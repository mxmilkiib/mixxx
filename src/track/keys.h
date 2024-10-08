#pragma once

#include <QByteArray>
#include <QList>
#include <QPair>

#include "proto/keys.pb.h"

#define KEY_MAP_VERSION "KeyMap-1.0"

typedef QList<QPair<mixxx::track::io::key::ChromaticKey, double>> KeyChangeList;

class Keys final {
  public:
    explicit Keys(const QByteArray* pByteArray = nullptr);

    // Serialization
    QByteArray toByteArray() const;

    // A string representing the version of the key-processing code that
    // produced this Keys instance. Used by KeysFactory for associating a given
    // serialization with the version that produced it.
    QString getVersion() const {
        return KEY_MAP_VERSION;
    }

    // A sub-version can be used to represent the preferences used to generate
    // the keys object.
    const QString& getSubVersion() const;
    void setSubVersion(const QString& subVersion);

    // Return the average key over the entire track if analyzed by Mixxx
    // or the Key found in the track metadata
    mixxx::track::io::key::ChromaticKey getGlobalKey() const;

    // Return key text form the track metadata literally (not normalized)
    QString getGlobalKeyText() const;

  private:
    explicit Keys(const mixxx::track::io::key::KeyMap& m_keyMap);

    bool readByteArray(const QByteArray& byteArray);

    QString m_subVersion;
    mixxx::track::io::key::KeyMap m_keyMap;

    // For private constructor access.
    friend class KeyFactory;
};

bool operator==(const Keys& lhs, const Keys& rhs);

inline bool operator!=(const Keys& lhs, const Keys& rhs) {
    return !(lhs == rhs);
}
