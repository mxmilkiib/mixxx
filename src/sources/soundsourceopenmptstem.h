#pragma once

#include <memory>
#include <vector>

#include "sources/soundsourceopenmpt.h"
#include "sources/soundsourceprovider.h"
#include "sources/trackerdsp.h"
#include "util/samplebuffer.h"

// forward declarations for openmpt types
namespace openmpt {
class module;
}

namespace mixxx {

// MARK: STEM-CAPABLE TRACKER MODULE DECODER

/// decodes tracker modules to 4-stem output using libopenmpt's channel muting
/// renders each stem by muting/unmuting specific channel groups
class SoundSourceOpenMPTStem : public SoundSource {
  public:
    static constexpr auto kChannelCount = mixxx::audio::ChannelCount::stereo();
    static constexpr auto kSampleRate = mixxx::audio::SampleRate(44100);
    static constexpr int kNumStems = 4;

    // apply settings for decoding
    static void configure(
            unsigned int bufferSizeLimit,
            const TrackerDSP::Settings& dspSettings);

    explicit SoundSourceOpenMPTStem(const QUrl& url);
    ~SoundSourceOpenMPTStem() override;

    std::pair<ImportResult, QDateTime> importTrackMetadataAndCoverImage(
            TrackMetadata* pTrackMetadata,
            QImage* pCoverArt,
            bool resetMissingTagMetadata) const override;

    void close() override;

  protected:
    ReadableSampleFrames readSampleFramesClamped(
            const WritableSampleFrames& sampleFrames) override;

  private:
    OpenResult tryOpen(
            OpenMode mode,
            const OpenParams& params) override;

    // channel-to-stem mapping strategies
    struct ChannelMapping {
        int stemIndex;    // which stem (0-3)
        int channelStart; // first channel in range
        int channelEnd;   // last channel in range (inclusive)
    };

    void calculateChannelMapping(int totalChannels);
    void renderStem(int stemIndex, CSAMPLE* pOutput, SINT frameCount);

    static unsigned int s_bufferSizeLimit;
    static TrackerDSP::Settings s_dspSettings;

    std::unique_ptr<openmpt::module> m_pModule;
    QByteArray m_fileBuf;

    // pre-decoded stem buffers (4 stems × stereo)
    typedef std::vector<CSAMPLE> ModSampleBuffer;
    std::array<ModSampleBuffer, kNumStems> m_stemBufs;

    // channel mapping for this module
    std::vector<ChannelMapping> m_channelMapping;
    int m_moduleChannelCount{0};

    // DSP effects (applied per-stem)
    std::array<TrackerDSP, kNumStems> m_stemDSP;

    // requested output mode
    mixxx::audio::ChannelCount m_requestedChannelCount;
    SampleBuffer m_readBuffer;
};

// MARK: SOUNDSOURCE PROVIDER

class SoundSourceProviderOpenMPTStem : public SoundSourceProvider {
  public:
    static const QString kDisplayName;

    QString getDisplayName() const override {
        return kDisplayName;
    }

    QStringList getSupportedFileTypes() const override;

    SoundSourceProviderPriority getPriorityHint(
            const QString& supportedFileType) const override;

    SoundSourcePointer newSoundSource(const QUrl& url) override {
        return newSoundSourceFromUrl<SoundSourceOpenMPTStem>(url);
    }
};

} // namespace mixxx
