#pragma once

#include <QDomElement>
#include <QList>
#include <QString>
#include <QtDebug>
#include <span>

#include "audio/types.h"
#include "util/compatibility/qhash.h"
#include "util/types.h"

/// Describes a group of channels, typically a pair for stereo sound in Mixxx.
class ChannelGroup {
  public:
    ChannelGroup(unsigned char channelBase, mixxx::audio::ChannelCount channels);
    unsigned char getChannelBase() const;
    mixxx::audio::ChannelCount getChannelCount() const;
    bool clashesWith(const ChannelGroup& other) const;

    uint hashValue() const {
        return (m_channels.value() << 8) |
                m_channelBase;
    }
    friend qhash_seed_t qHash(
            const ChannelGroup& group,
            qhash_seed_t seed = 0) {
        return qHash(group.hashValue(), seed);
    }

    friend bool operator==(
            const ChannelGroup& lhs,
            const ChannelGroup& rhs) {
        return lhs.m_channelBase == rhs.m_channelBase &&
                lhs.m_channels == rhs.m_channels;
    }

  private:
    unsigned char m_channelBase; // base (first) channel used on device
    mixxx::audio::ChannelCount m_channels; // number of channels used (s/b 2 in most cases)
};

inline bool operator!=(
        const ChannelGroup& lhs,
        const ChannelGroup& rhs) {
    return !(lhs == rhs);
}

/// Describes a path for audio to take.
///
/// TODO: Choose a better name for this class
class AudioPath {
public:
    /// Predefined types.
    ///
    /// If you add a new type here, be sure to add it to the various
    /// methods including getStringFromType, isIndexed, getTypeFromInt,
    /// channelsNeededForType (if necessary), the subclasses' getSupportedTypes
    /// (if necessary), etc.
  enum class AudioPathType : int {
      Main,
      Headphones,
      Booth,
      Bus,
      Deck,
      VinylControl,
      Microphone,
      Auxiliary,
      RecordBroadcast,
      Invalid, // if this isn't last bad things will happen -bkgood
  };
  AudioPath(unsigned char channelBase, mixxx::audio::ChannelCount channels);
  virtual ~AudioPath() = default;
  AudioPathType getType() const;
  ChannelGroup getChannelGroup() const;
  unsigned char getIndex() const;
  bool channelsClash(const AudioPath& other) const;
  QString getString() const;
  static QString getStringFromType(AudioPathType type);
  static QString getTrStringFromType(AudioPathType type, unsigned char index);
  static AudioPathType getTypeFromString(QString string);
  static bool isIndexed(AudioPathType type);
  static AudioPathType getTypeFromInt(int typeInt);

  /// Returns the minimum number of channels needed on a sound device for an
  /// AudioPathType.
  static mixxx::audio::ChannelCount minChannelsForType(AudioPathType type);

  // Returns the maximum number of channels needed on a sound device for an
  // AudioPathType.
  static mixxx::audio::ChannelCount maxChannelsForType(AudioPathType type);

  uint hashValue() const {
        // Exclude m_channelGroup from hash value!
        // See also: operator==()
        // TODO: Why??
        return (static_cast<int>(m_type) << 8) |
                m_index;
  }
    friend qhash_seed_t qHash(
            const AudioPath& path,
            qhash_seed_t seed = 0) {
        return qHash(path.hashValue(), seed);
    }

    // CppCoreGuidelines C.161: Use non-member functions for symmetric operators
    friend constexpr bool operator<(const AudioPath& lhs,
            const AudioPath& rhs) noexcept;
    friend constexpr bool operator==(const AudioPath& lhs,
            const AudioPath& rhs) noexcept;

  protected:
    virtual void setType(AudioPathType type) = 0;
    ChannelGroup m_channelGroup;
    AudioPathType m_type;
    unsigned char m_index;
};

// TODO: turn this into operator<=> once all targets fully support that
// XCode 14 probably and GCC 10
constexpr bool operator<(const AudioPath& lhs,
        const AudioPath& rhs) noexcept {
    // Exclude m_channelGroup from comparison!
    // See also: hashValue()/qHash()
    // TODO: Why??
    return std::tie(lhs.m_type, lhs.m_index) <
            std::tie(rhs.m_type, rhs.m_index);
}

constexpr bool operator==(const AudioPath& lhs,
        const AudioPath& rhs) noexcept {
    // Exclude m_channelGroup from comparison!
    // See also: hashValue()/qHash()
    // TODO: Why??
    return std::tie(lhs.m_type, lhs.m_index) ==
            std::tie(rhs.m_type, rhs.m_index);
}

/// A source of audio in Mixxx that is to be output to a group of
/// channels on an audio interface.
class AudioOutput : public AudioPath {
  public:
    AudioOutput(AudioPathType type,
            unsigned char channelBase,
            mixxx::audio::ChannelCount channels,
            unsigned char index = 0);
    ~AudioOutput() override = default;
    QDomElement toXML(QDomElement *element) const;
    static AudioOutput fromXML(const QDomElement &xml);
    static QList<AudioPathType> getSupportedTypes();
    bool isHidden() const {
        return m_type == AudioPathType::RecordBroadcast;
    }

  protected:
    void setType(AudioPathType type) override;
};

// This class is required to add the buffer, without changing the hash used as ID
class AudioOutputBuffer : public AudioOutput {
  public:
    AudioOutputBuffer(const AudioOutput& out, const CSAMPLE* pBuffer)
           : AudioOutput(out),
             m_pBuffer(pBuffer) {

    };
    ~AudioOutputBuffer() override = default;
    inline const CSAMPLE* getBuffer() const { return m_pBuffer; }
  private:
    const CSAMPLE* m_pBuffer;
};

/// A source of audio at a group of channels on an audio interface
/// that is be processed in Mixxx.
class AudioInput : public AudioPath {
  public:
    AudioInput(AudioPathType type = AudioPathType::Invalid,
            unsigned char channelBase = 0,
            mixxx::audio::ChannelCount channels = mixxx::audio::ChannelCount(),
            unsigned char index = 0);
    ~AudioInput() override;
    QDomElement toXML(QDomElement *element) const;
    static AudioInput fromXML(const QDomElement &xml);
    static QList<AudioPathType> getSupportedTypes();
    // implemented for regularity with AudioOutput
    bool isHidden() const {
        return false;
    }

  protected:
    void setType(AudioPathType type) override;
};

// This class is required to add the buffer, without changing the hash used as
// ID
class AudioInputBuffer : public AudioInput {
  public:
    AudioInputBuffer(const AudioInput& id, CSAMPLE* pBuffer)
            : AudioInput(id),
              m_pBuffer(pBuffer) {

    }
    ~AudioInputBuffer() override = default;
    inline CSAMPLE* getBuffer() const { return m_pBuffer; }
  private:
    CSAMPLE* m_pBuffer;
};


class AudioSource {
  public:
    virtual ~AudioSource() = default;

    virtual std::span<const CSAMPLE> buffer(const AudioOutput& output) const = 0;

    /// This is called by SoundManager whenever an output is connected for this
    /// source. When this is called it is guaranteed that no callback is
    /// active.
    virtual void onOutputConnected(const AudioOutput& output) {
        Q_UNUSED(output);
    };

    /// This is called by SoundManager whenever an output is disconnected for
    /// this source. When this is called it is guaranteed that no callback is
    /// active.
    virtual void onOutputDisconnected(const AudioOutput& output) {
        Q_UNUSED(output);
    };
};

class AudioDestination {
  public:
    virtual ~AudioDestination() = default;

    /// This is called by SoundManager whenever there are new samples from the
    /// configured input to be processed. This is run in the clock reference
    /// callback thread
    virtual void receiveBuffer(const AudioInput& input,
            const CSAMPLE* pBuffer,
            unsigned int iNumFrames) = 0;

    /// This is called by SoundManager whenever an input is configured for this
    /// destination. When this is called it is guaranteed that no callback is
    /// active.
    virtual void onInputConfigured(const AudioInput& input) {
        Q_UNUSED(input);
    };

    /// This is called by SoundManager whenever an input is unconfigured for this
    /// destination. When this is called it is guaranteed that no callback is
    /// active.
    virtual void onInputUnconfigured(const AudioInput& input) {
        Q_UNUSED(input);
    };
};

typedef AudioPath::AudioPathType AudioPathType;

class SoundDeviceId final {
  public:
    QString name;
    /// The "hw:X,Y" device name. Remains an empty string if not using ALSA
    /// or using a non-hw ALSA device such as "default" or "pulse".
    QString alsaHwDevice;
    int portAudioIndex;

    QString debugName() const;

    SoundDeviceId()
       : portAudioIndex(-1) {}
};

/// This must be registered with QMetaType::registerComparators for
/// QVariant::operator== to use it, which is required for QComboBox::findData to
/// work in DlgPrefSoundItem.
inline bool operator==(
        const SoundDeviceId& lhs,
        const SoundDeviceId& rhs) {
    return lhs.name == rhs.name
            && lhs.alsaHwDevice == rhs.alsaHwDevice
            && lhs.portAudioIndex == rhs.portAudioIndex;
}

inline bool operator!=(
        const SoundDeviceId& lhs,
        const SoundDeviceId& rhs) {
    return !(lhs == rhs);
}

/// There is not really a use case for this, but it is required for QMetaType::registerComparators.
inline bool operator<(const SoundDeviceId& lhs, const SoundDeviceId& rhs) {
    DEBUG_ASSERT(!"should never be invoked");
    return lhs.portAudioIndex < rhs.portAudioIndex;
}

Q_DECLARE_METATYPE(SoundDeviceId);

inline qhash_seed_t qHash(
        const SoundDeviceId& id,
        qhash_seed_t seed = 0) {
    return qHash(id.name, seed) ^
            qHash(id.alsaHwDevice, seed) ^
            qHash(id.portAudioIndex, seed);
}

inline QDebug operator<<(QDebug dbg, const SoundDeviceId& soundDeviceId) {
    return dbg << QString("SoundDeviceId(" + soundDeviceId.debugName() + ")");
}
