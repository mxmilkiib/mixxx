#pragma once

#include <QObject>
#include <QString>
#include <QSharedPointer>
#include <QHash>
#include <QMutex>

#include "control/control.h"

class ControlString;

// Internal string control implementation (similar to ControlDoublePrivate)
class ControlStringPrivate : public QObject {
    Q_OBJECT

  public:
    ControlStringPrivate(const ConfigKey& key,
                        ControlString* pCreatorCO,
                        bool bIgnoreNops = true,
                        bool bPersist = false,
                        const QString& defaultValue = "");
    ~ControlStringPrivate() override;

    // Gets the ControlStringPrivate matching the given ConfigKey
    static QSharedPointer<ControlStringPrivate> getControl(
            const ConfigKey& key,
            ControlFlags flags = ControlFlag::None,
            ControlString* pCreatorCO = nullptr,
            bool bIgnoreNops = true,
            bool bPersist = false,
            const QString& defaultValue = "");

    const QString& name() const { return m_name; }
    void setName(const QString& name) { m_name = name; }
    
    const QString& description() const { return m_description; }
    void setDescription(const QString& description) { m_description = description; }

    // Get/Set string value
    QString get() const;
    void set(const QString& value, QObject* pSetter);
    void setAndConfirm(const QString& value, QObject* pSetter);
    void reset();

    const QString& defaultValue() const { return m_defaultValue; }
    void setDefaultValue(const QString& value);

    bool ignoreNops() const { return m_bIgnoreNops; }

    // Connect value change request handler
    template <typename Receiver, typename Slot>
    bool connectValueChangeRequest(Receiver receiver, Slot func,
                                   Qt::ConnectionType type = Qt::AutoConnection) {
        return QObject::connect(this, &ControlStringPrivate::valueChangeRequest,
                               receiver, func, type);
    }

  signals:
    void valueChanged(const QString& value, QObject* pSetter);
    void valueChangeRequest(const QString& value);

  protected:
    ConfigKey m_key;
    QString m_name;
    QString m_description;
    mutable QMutex m_mutex;
    QString m_value;
    QString m_defaultValue;
    bool m_bIgnoreNops;
    bool m_bPersist;

  private:
    static QMutex s_controlStringMutex;
    static QHash<ConfigKey, QWeakPointer<ControlStringPrivate>> s_controlStringHash;
    static UserSettingsPointer s_pUserConfig;

    void initialize(const QString& value);
    void setValue(const QString& value, QObject* pSetter);
};

// String-based control object (parallel to ControlObject)
class ControlString : public QObject {
    Q_OBJECT

  public:
    ControlString();
    ControlString(const ConfigKey& key,
                 bool bIgnoreNops = true,
                 bool bPersist = false,
                 const QString& defaultValue = "");
    ~ControlString() override;

    // Static accessors
    static ControlString* getControl(const ConfigKey& key, ControlFlags flags = ControlFlag::None);
    static bool exists(const ConfigKey& key);
    static QString get(const ConfigKey& key);
    static void set(const ConfigKey& key, const QString& value);

    // Instance methods
    QString name() const;
    void setName(const QString& name);
    const QString description() const;
    void setDescription(const QString& description);

    ConfigKey getKey() const { return m_key; }

    QString get() const;
    void set(const QString& value);
    void setAndConfirm(const QString& value);
    void reset();

    QString defaultValue() const;
    void setDefaultValue(const QString& value);

    // Connect value change request handler
    template <typename Receiver, typename Slot>
    bool connectValueChangeRequest(Receiver receiver, Slot func,
                                   Qt::ConnectionType type = Qt::AutoConnection) {
        bool ret = false;
        if (m_pControl) {
            ret = m_pControl->connectValueChangeRequest(receiver, func, type);
        }
        return ret;
    }

    void setReadOnly();

  signals:
    void valueChanged(const QString& value);

  protected:
    ConfigKey m_key;
    QSharedPointer<ControlStringPrivate> m_pControl;

  private slots:
    void privateValueChanged(const QString& value, QObject* pSetter);
    void readOnlyHandler(const QString& value);

  private:
    ControlString(const ControlString&) = delete;
    ControlString& operator=(const ControlString&) = delete;
};
