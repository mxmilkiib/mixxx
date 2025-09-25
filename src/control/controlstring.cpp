#include "control/controlstring.h"

#include <QMutexLocker>
#include <QtDebug>

#include "moc_controlstring.cpp"
#include "util/assert.h"

// Static members
QMutex ControlStringPrivate::s_controlStringMutex;
QHash<ConfigKey, QWeakPointer<ControlStringPrivate>> ControlStringPrivate::s_controlStringHash;
UserSettingsPointer ControlStringPrivate::s_pUserConfig;

////////////////////////////////////////////////////////////////////////////////

ControlStringPrivate::ControlStringPrivate(const ConfigKey& key,
                                          ControlString* pCreatorCO,
                                          bool bIgnoreNops,
                                          bool bPersist,
                                          const QString& defaultValue)
        : m_key(key),
          m_name(key.group + "," + key.item),
          m_value(defaultValue),
          m_defaultValue(defaultValue),
          m_bIgnoreNops(bIgnoreNops),
          m_bPersist(bPersist) {
    Q_UNUSED(pCreatorCO);
    initialize(defaultValue);
}

ControlStringPrivate::~ControlStringPrivate() {
    if (m_bPersist && s_pUserConfig) {
        s_pUserConfig->set(ConfigKey("[String:" + m_key.group + "]", m_key.item), 
                          QVariant(m_value));
    }

    QMutexLocker locker(&s_controlStringMutex);
    s_controlStringHash.remove(m_key);
}

//static
QSharedPointer<ControlStringPrivate> ControlStringPrivate::getControl(
        const ConfigKey& key,
        ControlFlags flags,
        ControlString* pCreatorCO,
        bool bIgnoreNops,
        bool bPersist,
        const QString& defaultValue) {
    
    Q_UNUSED(flags);
    
    QMutexLocker locker(&s_controlStringMutex);
    
    auto it = s_controlStringHash.find(key);
    if (it != s_controlStringHash.end()) {
        auto pControl = it.value().toStrongRef();
        if (pControl) {
            return pControl;
        } else {
            // Clean up weak pointer
            s_controlStringHash.erase(it);
        }
    }
    
    // Create new control if pCreatorCO is provided
    if (pCreatorCO) {
        auto pControl = QSharedPointer<ControlStringPrivate>(
            new ControlStringPrivate(key, pCreatorCO, bIgnoreNops, bPersist, defaultValue));
        s_controlStringHash.insert(key, pControl.toWeakRef());
        return pControl;
    }
    
    return QSharedPointer<ControlStringPrivate>();
}

QString ControlStringPrivate::get() const {
    QMutexLocker locker(&m_mutex);
    return m_value;
}

void ControlStringPrivate::set(const QString& value, QObject* pSetter) {
    if (m_bIgnoreNops && value == get()) {
        return;
    }
    
    // Emit value change request - handler can block the change
    emit valueChangeRequest(value);
    
    // If no handler blocked it, set the value
    setValue(value, pSetter);
}

void ControlStringPrivate::setAndConfirm(const QString& value, QObject* pSetter) {
    setValue(value, pSetter);
}

void ControlStringPrivate::setValue(const QString& value, QObject* pSetter) {
    QMutexLocker locker(&m_mutex);
    
    if (m_bIgnoreNops && m_value == value) {
        return;
    }
    
    m_value = value;
    locker.unlock();
    
    emit valueChanged(value, pSetter);
}

void ControlStringPrivate::reset() {
    set(m_defaultValue, nullptr);
}

void ControlStringPrivate::setDefaultValue(const QString& value) {
    QMutexLocker locker(&m_mutex);
    m_defaultValue = value;
}

void ControlStringPrivate::initialize(const QString& value) {
    if (m_bPersist && s_pUserConfig) {
        QVariant storedValue = s_pUserConfig->getValue(
            ConfigKey("[String:" + m_key.group + "]", m_key.item), 
            QVariant(value));
        m_value = storedValue.toString();
    } else {
        m_value = value;
    }
}

////////////////////////////////////////////////////////////////////////////////

ControlString::ControlString()
        : m_key("[StringControl]", "undefined") {
}

ControlString::ControlString(const ConfigKey& key,
                           bool bIgnoreNops,
                           bool bPersist,
                           const QString& defaultValue)
        : m_key(key) {
    m_pControl = ControlStringPrivate::getControl(key, ControlFlag::None, this,
                                                 bIgnoreNops, bPersist, defaultValue);
    if (m_pControl) {
        connect(m_pControl.data(), &ControlStringPrivate::valueChanged,
                this, &ControlString::privateValueChanged,
                Qt::DirectConnection);
    }
}

ControlString::~ControlString() = default;

//static
ControlString* ControlString::getControl(const ConfigKey& key, ControlFlags flags) {
    Q_UNUSED(flags);
    // For simplicity, we don't maintain a registry of ControlString objects
    // like the double-based system does. Controllers should hold references.
    return nullptr;
}

//static
bool ControlString::exists(const ConfigKey& key) {
    QMutexLocker locker(&ControlStringPrivate::s_controlStringMutex);
    auto it = ControlStringPrivate::s_controlStringHash.find(key);
    return it != ControlStringPrivate::s_controlStringHash.end() && !it.value().isNull();
}

//static
QString ControlString::get(const ConfigKey& key) {
    auto pControl = ControlStringPrivate::getControl(key);
    return pControl ? pControl->get() : QString();
}

//static
void ControlString::set(const ConfigKey& key, const QString& value) {
    auto pControl = ControlStringPrivate::getControl(key);
    if (pControl) {
        pControl->set(value, nullptr);
    }
}

QString ControlString::name() const {
    return m_pControl ? m_pControl->name() : QString();
}

void ControlString::setName(const QString& name) {
    if (m_pControl) {
        m_pControl->setName(name);
    }
}

const QString ControlString::description() const {
    return m_pControl ? m_pControl->description() : QString();
}

void ControlString::setDescription(const QString& description) {
    if (m_pControl) {
        m_pControl->setDescription(description);
    }
}

QString ControlString::get() const {
    return m_pControl ? m_pControl->get() : QString();
}

void ControlString::set(const QString& value) {
    if (m_pControl) {
        m_pControl->set(value, this);
    }
}

void ControlString::setAndConfirm(const QString& value) {
    if (m_pControl) {
        m_pControl->setAndConfirm(value, this);
    }
}

void ControlString::reset() {
    if (m_pControl) {
        m_pControl->reset();
    }
}

QString ControlString::defaultValue() const {
    return m_pControl ? m_pControl->defaultValue() : QString();
}

void ControlString::setDefaultValue(const QString& value) {
    if (m_pControl) {
        m_pControl->setDefaultValue(value);
    }
}

void ControlString::setReadOnly() {
    if (m_pControl) {
        connect(m_pControl.data(), &ControlStringPrivate::valueChangeRequest,
                this, &ControlString::readOnlyHandler,
                Qt::DirectConnection);
    }
}

void ControlString::privateValueChanged(const QString& value, QObject* pSetter) {
    if (pSetter != this) {
        emit valueChanged(value);
    }
}

void ControlString::readOnlyHandler(const QString& value) {
    Q_UNUSED(value);
    qWarning() << "Read-only ControlString" << m_key.group << m_key.item
               << "received value change request.";
}
