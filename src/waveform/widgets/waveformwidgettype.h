#pragma once

#include <QFlags>
#include <array>
// required for Qt-Macros
#include <qobjectdefs.h>

class WaveformWidgetType {
  public:
    enum Type {
        // The order must not be changed because the waveforms are referenced
        // from the sorted preferences by a number.
        Empty = 0,
        Simple = 5,    // 5  Simple GL
        Filtered = 7,  // 7  Filtered GLSL
        HSV = 8,       // 8  HSV
        VSyncTest = 9, // 9  VSync GL
        RGB = 12,      // 12 RGB GLSL
        Stacked = 16,  // 16 RGB Stacked
        Layered = 17,    // 17 LMH bands stacked tail-to-tail
        Stems = 18,      // 18 Stem channels stacked tail-to-tail
        CQT = 19,        // 19 CQT-style spectrogram (frequency x time)
        LayeredRGB = 20, // 20 RGB bands stacked tail-to-tail
        Invalid,         // Don't use! Used to indicate invalid/unknown type, as
                         // Count_WaveformWidgetType used to.
    };
    static constexpr std::array kValues = {
            WaveformWidgetType::Empty,
            WaveformWidgetType::Simple,
            WaveformWidgetType::Filtered,
            WaveformWidgetType::HSV,
            WaveformWidgetType::VSyncTest,
            WaveformWidgetType::RGB,
            WaveformWidgetType::Stacked,
            WaveformWidgetType::Layered,
            WaveformWidgetType::Stems,
            WaveformWidgetType::CQT,
            WaveformWidgetType::LayeredRGB,
    };
};

enum class WaveformWidgetBackend {
    None = 0,
    GL,
    GLSL,
#ifdef MIXXX_USE_QOPENGL
    AllShader,
#endif
};
