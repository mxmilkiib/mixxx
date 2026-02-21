#include "waveformoverviewrenderer.h"

#include <QPainter>

#include "engine/engine.h"
#include "util/colorcomponents.h"
#include "util/math.h"
#include "util/timer.h"
#include "waveform/renderers/waveformsignalcolors.h"

namespace waveformOverviewRenderer {

QImage render(ConstWaveformPointer pWaveform,
        mixxx::OverviewType type,
        const WaveformSignalColors& signalColors,
        bool mono) {
    const int dataSize = pWaveform->getDataSize();
    if (dataSize <= 0) {
        return QImage();
    }

    QImage image(dataSize / 2, 2 * 255, QImage::Format_ARGB32_Premultiplied);
    image.fill(QColor(0, 0, 0, 0).value());

    QPainter painter(&image);
    painter.translate(0.0, static_cast<double>(image.height()) / 2.0);

    if (type == mixxx::OverviewType::HSV) {
        drawWaveformPartHSV(&painter,
                pWaveform,
                nullptr,
                dataSize,
                signalColors,
                mono);
    } else if (type == mixxx::OverviewType::Filtered) {
        drawWaveformPartLMH(&painter,
                pWaveform,
                nullptr,
                dataSize,
                signalColors,
                mono);
    } else if (type == mixxx::OverviewType::Layered) {
        drawWaveformPartLayered(&painter,
                pWaveform,
                nullptr,
                dataSize,
                signalColors,
                mono);
    } else if (type == mixxx::OverviewType::Stems) {
        drawWaveformPartStems(&painter,
                pWaveform,
                nullptr,
                dataSize,
                signalColors,
                mono);
    } else if (type == mixxx::OverviewType::Spectrographic) {
        drawWaveformPartSpectrographic(&painter,
                pWaveform,
                nullptr,
                dataSize,
                signalColors,
                mono);
    } else if (type == mixxx::OverviewType::Gradient) {
        drawWaveformPartGradient(&painter,
                pWaveform,
                nullptr,
                dataSize,
                signalColors,
                mono);
    } else {
        drawWaveformPartRGB(&painter,
                pWaveform,
                nullptr,
                dataSize,
                signalColors,
                mono);
    }

    // Evaluate waveform ratio peak
    float peak = 1;
    for (int i = 0; i < dataSize; i += 2) {
        peak = math_max3(
                peak,
                static_cast<float>(pWaveform->getAll(i)),
                static_cast<float>(pWaveform->getAll(i + 1)));
    }
    // Normalize
    float diffGain = 0;
    if (peak > 1) {
        diffGain = 255 - peak - 1;
    }

    const int topLeft = static_cast<int>(mono ? diffGain * 2 : diffGain);
    const QRect sourceRect(0,
            topLeft,
            image.width(),
            image.height() -
                    2 * static_cast<int>(diffGain));
    QImage croppedImage = image.copy(sourceRect);
    // Copy image, otherwise QPainter crashes when we alter it.
    QImage normImage = croppedImage.scaled(image.size(),
            Qt::IgnoreAspectRatio,
            Qt::SmoothTransformation);

    return normImage;
}

void drawWaveformPartRGB(
        QPainter* pPainter,
        ConstWaveformPointer pWaveform,
        int* start,
        int end,
        const WaveformSignalColors& signalColors,
        bool mono) {
    ScopedTimer t(QStringLiteral("waveformOverviewRenderer::drawNextPixmapPartRGB"));
    int startVal = 0;
    if (start) {
        startVal = *start;
    }

    const QColor lowColor = signalColors.getRgbLowColor();
    const QColor midColor = signalColors.getRgbMidColor();
    const QColor highColor = signalColors.getRgbHighColor();
    QColor color;

    float lowColor_r = 0, lowColor_g = 0, lowColor_b = 0,
          midColor_r = 0, midColor_g = 0, midColor_b = 0,
          highColor_r = 0, highColor_g = 0, highColor_b = 0,
          all = 0, low = 0, mid = 0, high = 0,
          red = 0, green = 0, blue = 0, max = 0;

    getRgbF(lowColor, &lowColor_r, &lowColor_g, &lowColor_b);
    getRgbF(midColor, &midColor_r, &midColor_g, &midColor_b);
    getRgbF(highColor, &highColor_r, &highColor_g, &highColor_b);

    if (mono) {
        // Mono means we're going to paint from bottom to top with l+r.
        const qreal dy = pPainter->deviceTransform().dy();
        pPainter->resetTransform();
        // shift y0 to bottom
        pPainter->translate(0, 2 * dy);
        // flip y-axis
        pPainter->scale(1, -1);
        for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
            // Left
            all = pWaveform->getAll(i) + pWaveform->getAll(i + 1);
            low = pWaveform->getLow(i) + pWaveform->getLow(i + 1);
            mid = pWaveform->getMid(i) + pWaveform->getMid(i + 1);
            high = pWaveform->getHigh(i) + pWaveform->getHigh(i + 1);

            red = low * lowColor_r + mid * midColor_r + high * highColor_r;
            green = low * lowColor_g + mid * midColor_g + high * highColor_g;
            blue = low * lowColor_b + mid * midColor_b + high * highColor_b;
            // Normalize
            max = math_max3(red, green, blue);
            // Draw
            if (max > 0.0) {
                color.setRgbF(static_cast<float>(low / max),
                        static_cast<float>(mid / max),
                        static_cast<float>(high / max));
                pPainter->setPen(color);
                pPainter->drawLine(x, static_cast<int>(all), x, 0);
            }
        }
    } else { // stereo
        for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
            // Left
            all = pWaveform->getAll(i);
            low = pWaveform->getLow(i);
            mid = pWaveform->getMid(i);
            high = pWaveform->getHigh(i);

            red = low * lowColor_r + mid * midColor_r + high * highColor_r;
            green = low * lowColor_g + mid * midColor_g + high * highColor_g;
            blue = low * lowColor_b + mid * midColor_b + high * highColor_b;
            // Normalize
            max = math_max3(red, green, blue);
            // Draw
            if (max > 0.0) {
                color.setRgbF(static_cast<float>(low / max),
                        static_cast<float>(mid / max),
                        static_cast<float>(high / max));
                pPainter->setPen(color);
                pPainter->drawLine(x, static_cast<int>(-all), x, 0);
            }

            // Right
            all = pWaveform->getAll(i + 1);
            low = pWaveform->getLow(i + 1);
            mid = pWaveform->getMid(i + 1);
            high = pWaveform->getHigh(i + 1);

            red = low * lowColor_r + mid * midColor_r + high * highColor_r;
            green = low * lowColor_g + mid * midColor_g + high * highColor_g;
            blue = low * lowColor_b + mid * midColor_b + high * highColor_b;

            max = math_max3(red, green, blue);

            if (max > 0.0) {
                color.setRgbF(static_cast<float>(low / max),
                        static_cast<float>(mid / max),
                        static_cast<float>(high / max));
                pPainter->setPen(color);
                pPainter->drawLine(x, 0, x, static_cast<int>(all));
            }
        }
    }

    if (start) {
        *start = end;
    }
}

void drawWaveformPartLMH(
        QPainter* pPainter,
        ConstWaveformPointer pWaveform,
        int* start,
        int end,
        const WaveformSignalColors& signalColors,
        bool mono) {
    ScopedTimer t(QStringLiteral("waveformOverviewRenderer::drawNextPixmapPartLMH"));
    const QColor lowColor = signalColors.getLowColor();
    const QColor midColor = signalColors.getMidColor();
    const QColor highColor = signalColors.getHighColor();
    int startVal = 0;
    if (start) {
        startVal = *start;
    }

    if (mono) {
        // Mono means we're going to paint from bottom to top with l+r.
        const qreal dy = pPainter->deviceTransform().dy();
        pPainter->resetTransform();
        // shift y0 to bottom
        pPainter->translate(0, 2 * dy);
        // flip y-axis
        pPainter->scale(1, -1);

        for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
            x = i / 2;
            pPainter->setPen(lowColor);
            pPainter->drawLine(QPoint(x, 0),
                    QPoint(x, pWaveform->getLow(i) + pWaveform->getLow(i + 1)));

            pPainter->setPen(midColor);
            pPainter->drawLine(QPoint(x, 0),
                    QPoint(x, pWaveform->getMid(i) + pWaveform->getMid(i + 1)));

            pPainter->setPen(highColor);
            pPainter->drawLine(QPoint(x, 0),
                    QPoint(x, pWaveform->getHigh(i) + pWaveform->getHigh(i + 1)));
        }
    } else { // stereo
        for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
            x = i / 2;
            pPainter->setPen(lowColor);
            pPainter->drawLine(QPoint(x, -pWaveform->getLow(i)),
                    QPoint(x, pWaveform->getLow(i + 1)));

            pPainter->setPen(midColor);
            pPainter->drawLine(QPoint(x, -pWaveform->getMid(i)),
                    QPoint(x, pWaveform->getMid(i + 1)));

            pPainter->setPen(highColor);
            pPainter->drawLine(QPoint(x, -pWaveform->getHigh(i)),
                    QPoint(x, pWaveform->getHigh(i + 1)));
        }
    }

    if (start) {
        *start = end;
    }
}

void drawWaveformPartHSV(
        QPainter* pPainter,
        ConstWaveformPointer pWaveform,
        int* start,
        int end,
        const WaveformSignalColors& signalColors,
        bool mono) {
    ScopedTimer t(QStringLiteral("waveformOverviewRenderer::drawNextPixmapPartHSV"));
    int startVal = 0;
    if (start) {
        startVal = *start;
    }

    float h = 0, s = 0, v = 0, lo = 0, hi = 0, total = 0;
    // Get HSV of low color.
    const QColor lowColor = signalColors.getLowColor();
    getHsvF(lowColor, &h, &s, &v);
    QColor color;

    unsigned char low[2] = {0, 0};
    unsigned char high[2] = {0, 0};
    unsigned char mid[2] = {0, 0};
    unsigned char all[2] = {0, 0};

    if (mono) {
        // Mono means we're going to paint from bottom to top with l+r.
        const qreal dy = pPainter->deviceTransform().dy();
        pPainter->resetTransform();
        // shift y0 to bottom
        pPainter->translate(0, 2 * dy);
        // flip y-axis
        pPainter->scale(1, -1);
    }

    for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
        x = i / 2;
        all[0] = pWaveform->getAll(i);
        all[1] = pWaveform->getAll(i + 1);

        if (!all[0] && !all[1]) {
            continue;
        }

        low[0] = pWaveform->getLow(i);
        low[1] = pWaveform->getLow(i + 1);
        mid[0] = pWaveform->getMid(i);
        mid[1] = pWaveform->getMid(i + 1);
        high[0] = pWaveform->getHigh(i);
        high[1] = pWaveform->getHigh(i + 1);

        total = (low[0] + low[1] + mid[0] + mid[1] +
                        high[0] + high[1]) *
                1.2f;

        // Prevent division by zero
        if (total > 0) {
            // Normalize low and high
            // (mid not need, because it not change the color)
            lo = (low[0] + low[1]) / total;
            hi = (high[0] + high[1]) / total;
        } else {
            lo = hi = 0.0;
        }

        // Set color
        color.setHsvF(h, 1.0f - hi, 1.0f - lo);

        if (mono) {
            pPainter->setPen(color);
            pPainter->drawLine(QPoint(i / 2, 0),
                    QPoint(i / 2, all[0] + all[1]));
        } else {
            pPainter->setPen(color);
            pPainter->drawLine(QPoint(i / 2, -all[0]),
                    QPoint(i / 2, all[1]));
        }
    }

    if (start) {
        *start = end;
    }
}

void drawWaveformPartLayered(
        QPainter* pPainter,
        ConstWaveformPointer pWaveform,
        int* start,
        int end,
        const WaveformSignalColors& signalColors,
        bool mono) {
    ScopedTimer t(QStringLiteral("waveformOverviewRenderer::drawNextPixmapPartLayered"));
    int startVal = 0;
    if (start) {
        startVal = *start;
    }

    const QColor lowColor = signalColors.getLowColor();
    const QColor midColor = signalColors.getMidColor();
    const QColor highColor = signalColors.getHighColor();

    // Bands are stacked tail-to-tail: low from 0, mid starts where low ends,
    // high starts where mid ends. Each band occupies its own segment of the
    // column height with no overlap.
    if (mono) {
        const qreal dy = pPainter->deviceTransform().dy();
        pPainter->resetTransform();
        pPainter->translate(0, 2 * dy);
        pPainter->scale(1, -1);

        for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
            const int low = pWaveform->getLow(i) + pWaveform->getLow(i + 1);
            const int mid = pWaveform->getMid(i) + pWaveform->getMid(i + 1);
            const int high = pWaveform->getHigh(i) + pWaveform->getHigh(i + 1);
            int base = 0;
            if (low > 0) {
                pPainter->setPen(lowColor);
                pPainter->drawLine(x, base, x, base + low);
            }
            base += low;
            if (mid > 0) {
                pPainter->setPen(midColor);
                pPainter->drawLine(x, base, x, base + mid);
            }
            base += mid;
            if (high > 0) {
                pPainter->setPen(highColor);
                pPainter->drawLine(x, base, x, base + high);
            }
        }
    } else { // stereo: left upward, right downward
        for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
            // Left channel — draw upward (negative y)
            int lowL = pWaveform->getLow(i);
            int midL = pWaveform->getMid(i);
            int highL = pWaveform->getHigh(i);
            int base = 0;
            if (lowL > 0) {
                pPainter->setPen(lowColor);
                pPainter->drawLine(x, -base, x, -(base + lowL));
            }
            base += lowL;
            if (midL > 0) {
                pPainter->setPen(midColor);
                pPainter->drawLine(x, -base, x, -(base + midL));
            }
            base += midL;
            if (highL > 0) {
                pPainter->setPen(highColor);
                pPainter->drawLine(x, -base, x, -(base + highL));
            }
            // Right channel — draw downward (positive y)
            int lowR = pWaveform->getLow(i + 1);
            int midR = pWaveform->getMid(i + 1);
            int highR = pWaveform->getHigh(i + 1);
            base = 0;
            if (lowR > 0) {
                pPainter->setPen(lowColor);
                pPainter->drawLine(x, base, x, base + lowR);
            }
            base += lowR;
            if (midR > 0) {
                pPainter->setPen(midColor);
                pPainter->drawLine(x, base, x, base + midR);
            }
            base += midR;
            if (highR > 0) {
                pPainter->setPen(highColor);
                pPainter->drawLine(x, base, x, base + highR);
            }
        }
    }

    if (start) {
        *start = end;
    }
}

void drawWaveformPartStems(
        QPainter* pPainter,
        ConstWaveformPointer pWaveform,
        int* start,
        int end,
        const WaveformSignalColors& signalColors,
        bool mono) {
    ScopedTimer t(QStringLiteral("waveformOverviewRenderer::drawNextPixmapPartStems"));
    int startVal = 0;
    if (start) {
        startVal = *start;
    }

    // Fixed distinct colours for up to 4 stems. These approximate the
    // typical stem colours used by Serato/Apple stem tracks.
    static const QColor kStemColors[mixxx::kMaxSupportedStems] = {
        QColor(0x4C, 0xAF, 0x50), // green  — drums
        QColor(0x21, 0x96, 0xF3), // blue   — bass
        QColor(0xFF, 0xC1, 0x07), // amber  — melody
        QColor(0xF4, 0x43, 0x36), // red    — vocals
    };

    // If no stem data is present, fall back to signal colour for all channel.
    if (!pWaveform->hasStem()) {
        const QColor fallback = signalColors.getSignalColor();
        if (mono) {
            const qreal dy = pPainter->deviceTransform().dy();
            pPainter->resetTransform();
            pPainter->translate(0, 2 * dy);
            pPainter->scale(1, -1);
            pPainter->setPen(fallback);
            for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
                const int all = pWaveform->getAll(i) + pWaveform->getAll(i + 1);
                if (all > 0) {
                    pPainter->drawLine(x, 0, x, all);
                }
            }
        } else {
            pPainter->setPen(fallback);
            for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
                const int allL = pWaveform->getAll(i);
                const int allR = pWaveform->getAll(i + 1);
                if (allL > 0 || allR > 0) {
                    pPainter->drawLine(x, -allL, x, allR);
                }
            }
        }
        if (start) {
            *start = end;
        }
        return;
    }

    // Stems stacked tail-to-tail, same direction as Layered.
    if (mono) {
        const qreal dy = pPainter->deviceTransform().dy();
        pPainter->resetTransform();
        pPainter->translate(0, 2 * dy);
        pPainter->scale(1, -1);

        for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
            int base = 0;
            for (int s = 0; s < mixxx::kMaxSupportedStems; ++s) {
                const int val = pWaveform->get(i).stems[s] +
                        pWaveform->get(i + 1).stems[s];
                if (val > 0) {
                    pPainter->setPen(kStemColors[s]);
                    pPainter->drawLine(x, base, x, base + val);
                    base += val;
                }
            }
        }
    } else {
        for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
            // Left channel upward
            int baseL = 0;
            for (int s = 0; s < mixxx::kMaxSupportedStems; ++s) {
                const int val = pWaveform->get(i).stems[s];
                if (val > 0) {
                    pPainter->setPen(kStemColors[s]);
                    pPainter->drawLine(x, -baseL, x, -(baseL + val));
                    baseL += val;
                }
            }
            // Right channel downward
            int baseR = 0;
            for (int s = 0; s < mixxx::kMaxSupportedStems; ++s) {
                const int val = pWaveform->get(i + 1).stems[s];
                if (val > 0) {
                    pPainter->setPen(kStemColors[s]);
                    pPainter->drawLine(x, baseR, x, baseR + val);
                    baseR += val;
                }
            }
        }
    }

    if (start) {
        *start = end;
    }
}

void drawWaveformPartSpectrographic(
        QPainter* pPainter,
        ConstWaveformPointer pWaveform,
        int* start,
        int end,
        const WaveformSignalColors& /*signalColors*/,
        bool mono) {
    ScopedTimer t(QStringLiteral("waveformOverviewRenderer::drawNextPixmapPartSpectrographic"));
    int startVal = 0;
    if (start) {
        startVal = *start;
    }

    // Spectrographic: height = all, colour = hue mapped across the spectrum
    // based on the low/mid/high balance. Low content shifts hue toward red
    // (0°), mid toward green (120°), high toward blue/violet (240°).
    // Saturation and value are fixed at 1.0 for maximum visibility.
    QColor color;

    if (mono) {
        const qreal dy = pPainter->deviceTransform().dy();
        pPainter->resetTransform();
        pPainter->translate(0, 2 * dy);
        pPainter->scale(1, -1);

        for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
            const int all = pWaveform->getAll(i) + pWaveform->getAll(i + 1);
            if (all <= 0) {
                continue;
            }
            const float low = pWaveform->getLow(i) + pWaveform->getLow(i + 1);
            const float mid = pWaveform->getMid(i) + pWaveform->getMid(i + 1);
            const float high = pWaveform->getHigh(i) + pWaveform->getHigh(i + 1);
            const float total = low + mid + high;
            const float hue = total > 0
                    ? (low * 0.0f + mid * 120.0f + high * 240.0f) / total
                    : 0.0f;
            color.setHsvF(hue / 360.0f, 1.0f, 1.0f);
            pPainter->setPen(color);
            pPainter->drawLine(x, 0, x, all);
        }
    } else {
        for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
            const int allL = pWaveform->getAll(i);
            const int allR = pWaveform->getAll(i + 1);
            if (allL <= 0 && allR <= 0) {
                continue;
            }
            // Derive hue from combined L+R band balance
            const float low = pWaveform->getLow(i) + pWaveform->getLow(i + 1);
            const float mid = pWaveform->getMid(i) + pWaveform->getMid(i + 1);
            const float high = pWaveform->getHigh(i) + pWaveform->getHigh(i + 1);
            const float total = low + mid + high;
            const float hue = total > 0
                    ? (low * 0.0f + mid * 120.0f + high * 240.0f) / total
                    : 0.0f;
            color.setHsvF(hue / 360.0f, 1.0f, 1.0f);
            pPainter->setPen(color);
            if (allL > 0) {
                pPainter->drawLine(x, 0, x, -allL);
            }
            if (allR > 0) {
                pPainter->drawLine(x, 0, x, allR);
            }
        }
    }

    if (start) {
        *start = end;
    }
}

void drawWaveformPartGradient(
        QPainter* pPainter,
        ConstWaveformPointer pWaveform,
        int* start,
        int end,
        const WaveformSignalColors& signalColors,
        bool mono) {
    ScopedTimer t(QStringLiteral("waveformOverviewRenderer::drawNextPixmapPartGradient"));
    int startVal = 0;
    if (start) {
        startVal = *start;
    }

    // Gradient: height = all, colour fades from full signal colour at the
    // centre line to transparent at the tip. Each pixel of the column is
    // drawn individually with alpha proportional to its distance from centre.
    const QColor base = signalColors.getSignalColor();
    const float br = base.redF();
    const float bg = base.greenF();
    const float bb = base.blueF();

    if (mono) {
        const qreal dy = pPainter->deviceTransform().dy();
        pPainter->resetTransform();
        pPainter->translate(0, 2 * dy);
        pPainter->scale(1, -1);

        for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
            const int all = pWaveform->getAll(i) + pWaveform->getAll(i + 1);
            if (all <= 0) {
                continue;
            }
            for (int y = 0; y <= all; ++y) {
                const float alpha = 1.0f - static_cast<float>(y) / static_cast<float>(all);
                QColor c;
                c.setRgbF(br, bg, bb, alpha);
                pPainter->setPen(c);
                pPainter->drawPoint(x, y);
            }
        }
    } else {
        for (int i = startVal, x = startVal / 2; i < end; i += 2, ++x) {
            const int allL = pWaveform->getAll(i);
            const int allR = pWaveform->getAll(i + 1);
            // Left channel — upward
            if (allL > 0) {
                for (int y = 0; y <= allL; ++y) {
                    const float alpha = 1.0f - static_cast<float>(y) / static_cast<float>(allL);
                    QColor c;
                    c.setRgbF(br, bg, bb, alpha);
                    pPainter->setPen(c);
                    pPainter->drawPoint(x, -y);
                }
            }
            // Right channel — downward
            if (allR > 0) {
                for (int y = 0; y <= allR; ++y) {
                    const float alpha = 1.0f - static_cast<float>(y) / static_cast<float>(allR);
                    QColor c;
                    c.setRgbF(br, bg, bb, alpha);
                    pPainter->setPen(c);
                    pPainter->drawPoint(x, y);
                }
            }
        }
    }

    if (start) {
        *start = end;
    }
}

} // namespace waveformOverviewRenderer
