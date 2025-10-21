#include "sources/soundsourceopenmptstem.h"

#include <QFile>
#include <libopenmpt/libopenmpt.hpp>

#include "audio/streaminfo.h"
#include "audio/types.h"
#include "track/trackmetadata.h"
#include "util/logger.h"
#include "util/sample.h"
#include "util/timer.h"

namespace mixxx {

namespace {

const Logger kLogger("SoundSourceOpenMPTStem");

const QStringList kSupportedFileTypes = {
        QStringLiteral("stem.mod"),
        QStringLiteral("stem.s3m"),
        QStringLiteral("stem.xm"),
        QStringLiteral("stem.it"),
        QStringLiteral("stem.mptm"),
};

/* read files in 512k chunks */
constexpr SINT kChunkSizeInBytes = SINT(1) << 19;

} // anonymous namespace

// MARK: STATIC MEMBERS

unsigned int SoundSourceOpenMPTStem::s_bufferSizeLimit = 0;
TrackerDSP::Settings SoundSourceOpenMPTStem::s_dspSettings;

void SoundSourceOpenMPTStem::configure(
        unsigned int bufferSizeLimit,
        const TrackerDSP::Settings& dspSettings) {
    s_bufferSizeLimit = bufferSizeLimit;
    s_dspSettings = dspSettings;
}

const QString SoundSourceProviderOpenMPTStem::kDisplayName =
        QStringLiteral("OpenMPT (Stems)");

QStringList SoundSourceProviderOpenMPTStem::getSupportedFileTypes() const {
    return kSupportedFileTypes;
}

SoundSourceProviderPriority SoundSourceProviderOpenMPTStem::getPriorityHint(
        const QString& supportedFileType) const {
    Q_UNUSED(supportedFileType)
    return SoundSourceProviderPriority::Higher;
}

// MARK: CONSTRUCTOR/DESTRUCTOR

SoundSourceOpenMPTStem::SoundSourceOpenMPTStem(const QUrl& url)
        : SoundSource(url, QStringLiteral("Module Stem")),
          m_pModule(nullptr) {
}

SoundSourceOpenMPTStem::~SoundSourceOpenMPTStem() {
    close();
}

// MARK: METADATA IMPORT

std::pair<MetadataSource::ImportResult, QDateTime>
SoundSourceOpenMPTStem::importTrackMetadataAndCoverImage(
        TrackMetadata* pTrackMetadata,
        QImage* pCoverArt,
        bool resetMissingTagMetadata) const {
    if (pTrackMetadata != nullptr) {
        QFile modFile(getLocalFileName());
        modFile.open(QIODevice::ReadOnly);
        const QByteArray fileBuf(modFile.readAll());
        modFile.close();

        try {
            std::unique_ptr<openmpt::module> pModule =
                    std::make_unique<openmpt::module>(
                            fileBuf.constData(),
                            fileBuf.size());

            // get metadata
            QString title = QString::fromStdString(pModule->get_metadata("title"));
            QString message = QString::fromStdString(pModule->get_metadata("message"));
            QString artist = QString::fromStdString(pModule->get_metadata("artist"));

            if (!title.isEmpty()) {
                pTrackMetadata->refTrackInfo().setTitle(title + " (Stems)");
            }
            if (!message.isEmpty()) {
                pTrackMetadata->refTrackInfo().setComment(message);
            }
            if (!artist.isEmpty()) {
                pTrackMetadata->refTrackInfo().setArtist(artist);
            }

            // get duration
            double durationSeconds = pModule->get_duration_seconds();

            pTrackMetadata->setStreamInfo(audio::StreamInfo{
                    audio::SignalInfo{
                            audio::ChannelCount::stem(),
                            kSampleRate,
                    },
                    audio::Bitrate(8),
                    Duration::fromMillis(static_cast<qint64>(durationSeconds * 1000)),
            });

            const auto sourceSynchronizedAt = getFileSynchronizedAt(modFile);
            return std::make_pair(ImportResult::Succeeded, sourceSynchronizedAt);
        } catch (const openmpt::exception& e) {
            kLogger.warning() << "failed to load module for metadata:" << e.what();
            return std::make_pair(ImportResult::Failed, QDateTime());
        }
    }

    return MetadataSourceTagLib::importTrackMetadataAndCoverImage(
            nullptr, pCoverArt, resetMissingTagMetadata);
}

// MARK: CHANNEL MAPPING

void SoundSourceOpenMPTStem::calculateChannelMapping(int totalChannels) {
    m_channelMapping.clear();
    m_moduleChannelCount = totalChannels;

    kLogger.info() << "calculating channel mapping for" << totalChannels << "channels";

    if (totalChannels <= 0) {
        kLogger.warning() << "invalid channel count:" << totalChannels;
        return;
    }

    // mapping strategies based on channel count
    if (totalChannels <= 4) {
        // 1-4 channels: one channel per stem (pad if needed)
        for (int ch = 0; ch < totalChannels; ++ch) {
            m_channelMapping.push_back({ch, ch, ch});
        }
        // pad remaining stems with no channels
        for (int stem = totalChannels; stem < kNumStems; ++stem) {
            m_channelMapping.push_back({stem, -1, -1});
        }
    } else if (totalChannels <= 8) {
        // 5-8 channels: group into 4 stems
        int chPerStem = (totalChannels + kNumStems - 1) / kNumStems;
        for (int stem = 0; stem < kNumStems; ++stem) {
            int start = stem * chPerStem;
            int end = std::min(start + chPerStem - 1, totalChannels - 1);
            if (start < totalChannels) {
                m_channelMapping.push_back({stem, start, end});
            } else {
                m_channelMapping.push_back({stem, -1, -1});
            }
        }
    } else {
        // >8 channels: distribute evenly across 4 stems
        int chPerStem = totalChannels / kNumStems;
        int remainder = totalChannels % kNumStems;
        int currentCh = 0;

        for (int stem = 0; stem < kNumStems; ++stem) {
            int stemChannels = chPerStem + (stem < remainder ? 1 : 0);
            if (stemChannels > 0) {
                m_channelMapping.push_back(
                        {stem, currentCh, currentCh + stemChannels - 1});
                currentCh += stemChannels;
            } else {
                m_channelMapping.push_back({stem, -1, -1});
            }
        }
    }

    // log the mapping
    for (const auto& mapping : m_channelMapping) {
        if (mapping.channelStart >= 0) {
            kLogger.info() << "stem" << mapping.stemIndex << ":" << "channels"
                           << mapping.channelStart << "-" << mapping.channelEnd;
        } else {
            kLogger.info() << "stem" << mapping.stemIndex << ": empty (padded)";
        }
    }
}

// MARK: STEM RENDERING

void SoundSourceOpenMPTStem::renderStem(int stemIndex, CSAMPLE* pOutput, SINT frameCount) {
    DEBUG_ASSERT(stemIndex >= 0 && stemIndex < kNumStems);
    DEBUG_ASSERT(m_pModule);

    // find the channel mapping for this stem
    const ChannelMapping* mapping = nullptr;
    for (const auto& m : m_channelMapping) {
        if (m.stemIndex == stemIndex) {
            mapping = &m;
            break;
        }
    }

    if (!mapping || mapping->channelStart < 0) {
        // empty stem, output silence
        SampleUtil::clear(pOutput, frameCount * kChannelCount);
        return;
    }

    // reset module position
    m_pModule->set_position_seconds(0.0);

    // mute all channels
    for (int ch = 0; ch < m_moduleChannelCount; ++ch) {
        m_pModule->set_channel_mute_status(ch, true);
    }

    // unmute only the channels for this stem
    for (int ch = mapping->channelStart; ch <= mapping->channelEnd; ++ch) {
        m_pModule->set_channel_mute_status(ch, false);
    }

    // render the stem
    const size_t framesRead = m_pModule->read_interleaved_stereo(
            kSampleRate,
            frameCount,
            pOutput);

    // pad with silence if needed
    if (framesRead < static_cast<size_t>(frameCount)) {
        const SINT samplesRead = framesRead * kChannelCount;
        const SINT samplesToFill = frameCount * kChannelCount - samplesRead;
        SampleUtil::clear(pOutput + samplesRead, samplesToFill);
    }
}

// MARK: OPEN/CLOSE

SoundSource::OpenResult SoundSourceOpenMPTStem::tryOpen(
        OpenMode /*mode*/,
        const OpenParams& params) {
    ScopedTimer t(QStringLiteral("SoundSourceOpenMPTStem::open()"));

    // read module file to byte array
    const QString fileName(getLocalFileName());
    QFile modFile(fileName);
    kLogger.debug() << "loading openmpt module for stems" << modFile.fileName();
    modFile.open(QIODevice::ReadOnly);
    m_fileBuf = modFile.readAll();
    modFile.close();

    // create openmpt module
    try {
        m_pModule = std::make_unique<openmpt::module>(
                m_fileBuf.constData(),
                m_fileBuf.size());
    } catch (const openmpt::exception& e) {
        kLogger.debug() << "could not load module file:" << fileName << "-" << e.what();
        return OpenResult::Failed;
    }

    // get channel count and calculate mapping
    m_moduleChannelCount = m_pModule->get_num_channels();
    calculateChannelMapping(m_moduleChannelCount);

    // check requested channel mode
    uint selectedStemMask = params.stemMask();
    if (params.getSignalInfo().getChannelCount() == audio::ChannelCount::stereo() ||
            selectedStemMask) {
        m_requestedChannelCount = audio::ChannelCount::stereo();
    } else {
        m_requestedChannelCount = audio::ChannelCount::stem();
    }

    // configure DSP for each stem
    for (int stem = 0; stem < kNumStems; ++stem) {
        m_stemDSP[stem].configure(s_dspSettings, kSampleRate);
    }

    DEBUG_ASSERT(0 == (kChunkSizeInBytes % sizeof(CSAMPLE)));
    const SINT chunkSizeInSamples = kChunkSizeInBytes / sizeof(CSAMPLE);

    const ModSampleBuffer::size_type bufferSizeLimitInSamples =
            s_bufferSizeLimit / sizeof(CSAMPLE);

    // estimate size
    const ModSampleBuffer::size_type estimateSeconds =
            static_cast<ModSampleBuffer::size_type>(m_pModule->get_duration_seconds());
    const ModSampleBuffer::size_type estimateSamples =
            estimateSeconds * kChannelCount * kSampleRate;

    // render each stem
    kLogger.debug() << "rendering" << kNumStems << "stems";
    for (int stem = 0; stem < kNumStems; ++stem) {
        m_stemBufs[stem].reserve(std::min(estimateSamples, bufferSizeLimitInSamples));

        std::vector<float> tempBuffer(chunkSizeInSamples);
        while (m_stemBufs[stem].size() < bufferSizeLimitInSamples) {
            const ModSampleBuffer::size_type currentSize = m_stemBufs[stem].size();
            const SINT framesToRead = chunkSizeInSamples / kChannelCount;

            renderStem(stem, tempBuffer.data(), framesToRead);

            const size_t samplesRendered = framesToRead * kChannelCount;
            m_stemBufs[stem].resize(currentSize + samplesRendered);
            std::copy(tempBuffer.begin(),
                    tempBuffer.begin() + samplesRendered,
                    m_stemBufs[stem].begin() + currentSize);

            // check if we've reached the end
            if (m_pModule->get_position_seconds() >= m_pModule->get_duration_seconds()) {
                break;
            }
        }

        kLogger.debug() << "stem" << stem << ":" << m_stemBufs[stem].size() << "samples";

        // apply DSP effects
        if (s_dspSettings.reverbEnabled || s_dspSettings.megabassEnabled ||
                s_dspSettings.surroundEnabled || s_dspSettings.noiseReductionEnabled) {
            const SINT frameCount = m_stemBufs[stem].size() / kChannelCount;
            m_stemDSP[stem].processStereo(m_stemBufs[stem].data(), frameCount);
        }
    }

    // determine final output channel count
    if (m_requestedChannelCount == audio::ChannelCount::stereo()) {
        initChannelCountOnce(audio::ChannelCount::stereo());
    } else {
        initChannelCountOnce(audio::ChannelCount::stem());
    }

    initSampleRateOnce(kSampleRate);

    // use the longest stem for frame count
    SINT maxFrames = 0;
    for (int stem = 0; stem < kNumStems; ++stem) {
        const SINT stemFrames = m_stemBufs[stem].size() / kChannelCount;
        maxFrames = std::max(maxFrames, stemFrames);
    }

    initFrameIndexRangeOnce(IndexRange::forward(0, maxFrames));

    return OpenResult::Succeeded;
}

void SoundSourceOpenMPTStem::close() {
    m_pModule.reset();
    for (auto& buf : m_stemBufs) {
        buf.clear();
        buf.shrink_to_fit();
    }
}

// MARK: SAMPLE READING

ReadableSampleFrames SoundSourceOpenMPTStem::readSampleFramesClamped(
        const WritableSampleFrames& writableSampleFrames) {
    const SINT readFrameCount = writableSampleFrames.frameLength();
    const SINT readFrameIndex = writableSampleFrames.frameIndexRange().start();

    CSAMPLE* pBuffer = writableSampleFrames.writableData();

    if (m_requestedChannelCount == audio::ChannelCount::stereo()) {
        // stereo mode: mix all stems together
        SampleUtil::clear(pBuffer, writableSampleFrames.writableLength());

        for (int stem = 0; stem < kNumStems; ++stem) {
            const SINT readOffset = readFrameIndex * kChannelCount;
            const SINT readSamples = readFrameCount * kChannelCount;

            if (readOffset + readSamples > static_cast<SINT>(m_stemBufs[stem].size())) {
                continue;
            }

            // mix this stem into the output
            SampleUtil::add(pBuffer,
                    m_stemBufs[stem].data() + readOffset,
                    readSamples);
        }
    } else {
        // stem mode: interleave all stems
        const SINT stemSampleLength = readFrameCount * kChannelCount;

        // allocate temp buffer if needed
        if (stemSampleLength > m_readBuffer.size()) {
            m_readBuffer = SampleBuffer(stemSampleLength);
        }

        for (int stem = 0; stem < kNumStems; ++stem) {
            const SINT readOffset = readFrameIndex * kChannelCount;
            const SINT readSamples = readFrameCount * kChannelCount;

            // copy stem to temp buffer
            if (readOffset + readSamples <= static_cast<SINT>(m_stemBufs[stem].size())) {
                std::copy(m_stemBufs[stem].begin() + readOffset,
                        m_stemBufs[stem].begin() + readOffset + readSamples,
                        m_readBuffer.data());
            } else {
                SampleUtil::clear(m_readBuffer.data(), readSamples);
            }

            // interleave into output (same pattern as SoundSourceSTEM)
            for (SINT i = 0; i < readFrameCount; ++i) {
                pBuffer[2 * kNumStems * i + 2 * stem] = m_readBuffer[2 * i];
                pBuffer[2 * kNumStems * i + 2 * stem + 1] = m_readBuffer[2 * i + 1];
            }
        }
    }

    return ReadableSampleFrames(
            writableSampleFrames.frameIndexRange(),
            SampleBuffer::ReadableSlice(
                    writableSampleFrames.writableData(),
                    writableSampleFrames.writableLength()));
}

} // namespace mixxx
