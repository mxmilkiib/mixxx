#include "waveform/renderers/allshader/waveformrenderercqt.h"

#include "rendergraph/material/rgbmaterial.h"
#include "rendergraph/vertexupdaters/rgbvertexupdater.h"
#include "track/track.h"
#include "util/math.h"
#include "waveform/renderers/waveformwidgetrenderer.h"
#include "waveform/waveform.h"

using namespace rendergraph;

namespace allshader {

// Sub-bins per frequency band per channel half.
// Each band is subdivided to give a smooth spectrogram gradient.
static constexpr int kBinsPerBand = 8;
// Total rows per pixel column per channel: 3 bands x kBinsPerBand
static constexpr int kRowsPerChannel = 3 * kBinsPerBand;

WaveformRendererCQT::WaveformRendererCQT(
        WaveformWidgetRenderer* waveformWidget,
        ::WaveformRendererSignalBase::Options options)
        : WaveformRendererSignalBase(waveformWidget, options) {
    initForRectangles<RGBMaterial>(0);
    setUsePreprocess(true);
}

void WaveformRendererCQT::onSetup(const QDomNode&) {
}

void WaveformRendererCQT::preprocess() {
    if (!preprocessInner()) {
        if (geometry().vertexCount() != 0) {
            geometry().allocate(0);
            markDirtyGeometry();
        }
    }
}

bool WaveformRendererCQT::preprocessInner() {
    TrackPointer pTrack = m_waveformRenderer->getTrackInfo();
    if (!pTrack) {
        return false;
    }

    ConstWaveformPointer waveform = pTrack->getWaveform();
    if (waveform.isNull()) {
        return false;
    }

    const int dataSize = waveform->getDataSize();
    if (dataSize <= 1) {
        return false;
    }

    const WaveformData* data = waveform->data();
    if (data == nullptr) {
        return false;
    }
#ifdef __STEM__
    auto stemInfo = pTrack->getStemInfo();
    if (!stemInfo.isEmpty() && waveform->hasStem() && !m_ignoreStem) {
        return false;
    }
#endif

    const float devicePixelRatio = m_waveformRenderer->getDevicePixelRatio();
    const int length = static_cast<int>(m_waveformRenderer->getLength());
    const int pixelLength = static_cast<int>(m_waveformRenderer->getLength() * devicePixelRatio);
    const float invDevicePixelRatio = 1.f / devicePixelRatio;
    const float halfPixelSize = 0.5f / devicePixelRatio;

    const int visualFramesSize = dataSize / 2;
    const double firstVisualFrame =
            m_waveformRenderer->getFirstDisplayedPosition() * visualFramesSize;
    const double lastVisualFrame =
            m_waveformRenderer->getLastDisplayedPosition() * visualFramesSize;
    const double visualIncrementPerPixel =
            (lastVisualFrame - firstVisualFrame) / static_cast<double>(pixelLength);

    float allGain{1.0};
    float bandGain[3] = {1.0, 1.0, 1.0};
    getGains(&allGain, &bandGain[0], &bandGain[1], &bandGain[2]);

    const float breadth = static_cast<float>(m_waveformRenderer->getBreadth());
    const float halfBreadth = breadth / 2.0f;
    const float rowHeight = halfBreadth / static_cast<float>(kRowsPerChannel);

    double xVisualFrame = qRound(firstVisualFrame / visualIncrementPerPixel) *
            visualIncrementPerPixel;

    const int numVerticesPerLine = 6; // 2 triangles per rectangle
    // axis line + (kRowsPerChannel rows x 2 channels) per pixel column
    const int reserved = numVerticesPerLine * (1 + pixelLength * kRowsPerChannel * 2);

    geometry().setDrawingMode(Geometry::DrawingMode::Triangles);
    geometry().allocate(reserved);
    markDirtyGeometry();

    RGBVertexUpdater vertexUpdater{geometry().vertexDataAs<Geometry::RGBColoredPoint2D>()};

    // Centre axis line
    vertexUpdater.addRectangle(
            {0.f, halfBreadth - 0.5f},
            {static_cast<float>(length), halfBreadth + 0.5f},
            {static_cast<float>(m_axesColor_r),
                    static_cast<float>(m_axesColor_g),
                    static_cast<float>(m_axesColor_b)});

    const double maxSamplingRange = visualIncrementPerPixel / 2.0;

    // CQT-style hues: low=0 (red), mid=120 (green), high=240 (blue)
    // matching ffmpeg showcqt's default colour mapping
    static constexpr float kBandHue[3] = {0.0f, 120.0f, 240.0f};

    for (int pos = 0; pos < pixelLength; ++pos) {
        const int visualFrameStart = std::lround(xVisualFrame - maxSamplingRange);
        const int visualFrameStop = std::lround(xVisualFrame + maxSamplingRange);

        const int visualIndexStart = std::max(visualFrameStart * 2, 0);
        const int visualIndexStop =
                std::min(std::max(visualFrameStop, visualFrameStart + 1) * 2, dataSize - 1);

        const float fpos = static_cast<float>(pos) * invDevicePixelRatio;

        // Gather max per band per channel
        uchar u8max[3][2]{};
        for (int chn = 0; chn < 2; chn++) {
            for (int i = visualIndexStart + chn; i < visualIndexStop + chn; i += 2) {
                const WaveformData& wd = data[i];
                u8max[0][chn] = math_max(u8max[0][chn], wd.filtered.low);
                u8max[1][chn] = math_max(u8max[1][chn], wd.filtered.mid);
                u8max[2][chn] = math_max(u8max[2][chn], wd.filtered.high);
            }
        }

        // For each channel, for each band, for each sub-bin render a thin row.
        // Left (chn=0): rows go upward from centre.
        // Right (chn=1): rows go downward from centre.
        for (int chn = 0; chn < 2; chn++) {
            const float channelSign = (chn == 0) ? -1.f : 1.f;

            for (int band = 0; band < 3; band++) {
                const float amplitude =
                        static_cast<float>(u8max[band][chn]) *
                        bandGain[band] * allGain / 255.f;

                const int bandBase = band * kBinsPerBand;

                for (int bin = 0; bin < kBinsPerBand; bin++) {
                    // Linear falloff from full amplitude at bin 0 to zero at kBinsPerBand
                    const float binFrac =
                            static_cast<float>(bin) / static_cast<float>(kBinsPerBand);
                    const float binAmplitude = amplitude * (1.f - binFrac);

                    if (binAmplitude < 1.f / 255.f) {
                        // Zero-size degenerate rectangle to keep vertex count exact
                        vertexUpdater.addRectangle(
                                {fpos, halfBreadth},
                                {fpos, halfBreadth},
                                {0.f, 0.f, 0.f});
                        continue;
                    }

                    const int rowIndex = bandBase + bin;
                    const float yInner = halfBreadth +
                            channelSign * static_cast<float>(rowIndex) * rowHeight;
                    const float yOuter = halfBreadth +
                            channelSign * static_cast<float>(rowIndex + 1) * rowHeight;

                    // HSV to RGB: hue from band, S=1, V=binAmplitude
                    const float hue = kBandHue[band] / 360.f;
                    const float h6 = hue * 6.f;
                    const int hi = static_cast<int>(h6) % 6;
                    const float f = h6 - static_cast<float>(static_cast<int>(h6));
                    const float v = binAmplitude;
                    const float q = v * (1.f - f);
                    const float t = v * f;
                    float r, g, b;
                    switch (hi) {
                    case 0:  r = v; g = t; b = 0; break;
                    case 1:  r = q; g = v; b = 0; break;
                    case 2:  r = 0; g = v; b = t; break;
                    case 3:  r = 0; g = q; b = v; break;
                    case 4:  r = t; g = 0; b = v; break;
                    default: r = v; g = 0; b = q; break;
                    }

                    const float yTop = std::min(yInner, yOuter);
                    const float yBot = std::max(yInner, yOuter);
                    vertexUpdater.addRectangle(
                            {fpos - halfPixelSize, yTop},
                            {fpos + halfPixelSize, yBot},
                            {r, g, b});
                }
            }
        }

        xVisualFrame += visualIncrementPerPixel;
    }

    DEBUG_ASSERT(reserved == vertexUpdater.index());

    markDirtyMaterial();
    return true;
}

} // namespace allshader
