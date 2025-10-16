#include "widget/wsplitter.h"

#include <QEvent>
#include <QList>
#include <QMouseEvent>
#include <QSplitterHandle>

#include "moc_wsplitter.cpp"
#include "skin/legacy/skincontext.h"

WSplitter::WSplitter(QWidget* pParent, UserSettingsPointer pConfig)
        : QSplitter(pParent),
          WBaseWidget(this),
          m_pConfig(pConfig) {
    connect(this, &WSplitter::splitterMoved, this, &WSplitter::slotSplitterMoved);
}

void WSplitter::setup(const QDomNode& node, const SkinContext& context) {
    // Load split sizes
    QString sizesJoined;
    QString msg;
    bool ok = false;

    // Default orientation is horizontal. For vertical splitters, the orientation must be set
    // before calling setSizes() for reloading the saved state to work.
    QString layout;
    if (context.hasNodeSelectString(node, "Orientation", &layout)) {
        if (layout == "vertical") {
            setOrientation(Qt::Vertical);
        } else if (layout == "horizontal") {
            setOrientation(Qt::Horizontal);
        }
    }

    // Try to load last values stored in mixxx.cfg
    QString splitSizesConfigKey;
    if (context.hasNodeSelectString(node, "SplitSizesConfigKey", &splitSizesConfigKey)) {
        m_configKey = ConfigKey::parseCommaSeparated(splitSizesConfigKey);

        if (m_pConfig->exists(m_configKey)) {
            sizesJoined = m_pConfig->getValueString(m_configKey);
            msg = "Reading .cfg file: '" + m_configKey.group + " " +
                    m_configKey.item + " " + sizesJoined +
                    "' does not match the number of children nodes:" +
                    QString::number(count());
            ok = true;
        }
    }

    // nothing in mixxx.cfg? Load default values
    if (!ok && context.hasNodeSelectString(node, "SplitSizes", &sizesJoined)) {
        msg = "<SplitSizes> for <Splitter> (" + sizesJoined +
                ") does not match the number of children nodes:" +
                QString::number(count());
    }

    // found some value for splitsizes?
    if (!sizesJoined.isEmpty()) {
        const QStringList sizesSplit = sizesJoined.split(",");
        QList<int> sizesList;
        ok = false;
        for (const QString& sizeStr : sizesSplit) {
            sizesList.push_back(sizeStr.toInt(&ok));
            if (!ok) {
                break;
            }
        }
        if (sizesList.length() != count()) {
            SKIN_WARNING(node, context, msg);
            ok = false;
        }
        if (ok) {
            this->setSizes(sizesList);
        }
    }

    // Which children can be collapsed?
    QString collapsibleJoined;
    if (context.hasNodeSelectString(node, "Collapsible", &collapsibleJoined)) {
        const QStringList collapsibleSplit = collapsibleJoined.split(",");
        QList<bool> collapsibleList;
        ok = false;
        for (const QString& collapsibleStr : collapsibleSplit) {
            collapsibleList.push_back(collapsibleStr.toInt(&ok)>0);
            if (!ok) {
                break;
            }
        }
        if (collapsibleList.length() != count()) {
            msg = "<Collapsible> for <Splitter> (" + collapsibleJoined +
                    ") does not match the number of children nodes:" +
                    QString::number(count());
            SKIN_WARNING(node, context, msg);
            ok = false;
        }
        if (ok) {
            int i = 0;
            for (bool collapsible : collapsibleList) {
                setCollapsible(i++, collapsible);
            }
        }
    }

    // create control objects for pane sizes if control key prefix specified
    QString controlKeyPrefix;
    if (context.hasNodeSelectString(node, "ControlKeyPrefix", &controlKeyPrefix)) {
        createControls(controlKeyPrefix);
    }
}

void WSplitter::slotSplitterMoved() {
    if (!m_configKey.group.isEmpty() && !m_configKey.item.isEmpty()) {
        QStringList sizeStrList;
        const auto sizesIntList = sizes();
        for (const int& sizeInt : sizesIntList) {
            sizeStrList.push_back(QString::number(sizeInt));
        }
        QString sizesStr = sizeStrList.join(",");
        m_pConfig->set(m_configKey, ConfigValue(sizesStr));
    }
    updateControls();
}

void WSplitter::createControls(const QString& controlKeyPrefix) {
    m_paneControls.clear();
    const int numPanes = count();

    for (int i = 0; i < numPanes; ++i) {
        QString controlName = QString("%1_%2").arg(controlKeyPrefix).arg(i);
        auto pControl = std::make_unique<ControlObject>(
                ConfigKey("[Library]", controlName), false);
        connect(pControl.get(),
                &ControlObject::valueChanged,
                this,
                &WSplitter::slotControlValueChanged);
        m_paneControls.push_back(std::move(pControl));
    }

    updateControls();
}

void WSplitter::updateControls() {
    if (m_paneControls.empty()) {
        return;
    }

    const auto currentSizes = sizes();
    for (size_t i = 0; i < m_paneControls.size() && i < static_cast<size_t>(currentSizes.size()); ++i) {
        m_paneControls[i]->set(currentSizes[i]);
    }
}

void WSplitter::slotControlValueChanged(double value) {
    ControlObject* pSender = qobject_cast<ControlObject*>(sender());
    if (!pSender) {
        return;
    }

    // find which control was changed
    for (size_t i = 0; i < m_paneControls.size(); ++i) {
        if (m_paneControls[i].get() == pSender) {
            auto currentSizes = sizes();
            if (i < static_cast<size_t>(currentSizes.size())) {
                currentSizes[i] = static_cast<int>(value);
                setSizes(currentSizes);
            }
            break;
        }
    }
}

bool WSplitter::event(QEvent* pEvent) {
    if (pEvent->type() == QEvent::ToolTip) {
        updateTooltip();
    }
    return QSplitter::event(pEvent);
}

void WSplitter::mouseDoubleClickEvent(QMouseEvent* pEvent) {
    // check if double-click is on a splitter handle
    QSplitterHandle* pHandle = qobject_cast<QSplitterHandle*>(childAt(pEvent->pos()));
    if (!pHandle) {
        QSplitter::mouseDoubleClickEvent(pEvent);
        return;
    }

    // find which handle was clicked
    int handleIndex = indexOf(pHandle);
    if (handleIndex < 0) {
        QSplitter::mouseDoubleClickEvent(pEvent);
        return;
    }

    // toggle first pane (index 0) between collapsed and saved size
    // this is typically the sidebar when used with LibrarySplitter
    QList<int> currentSizes = sizes();
    if (currentSizes.isEmpty() || handleIndex >= currentSizes.size()) {
        QSplitter::mouseDoubleClickEvent(pEvent);
        return;
    }

    if (currentSizes[0] == 0) {
        // restore from saved sizes
        if (!m_savedSizes.isEmpty() && m_savedSizes[0] > 0) {
            setSizes(m_savedSizes);
        }
    } else {
        // save current sizes and collapse first pane
        m_savedSizes = currentSizes;
        currentSizes[0] = 0;
        setSizes(currentSizes);
    }

    pEvent->accept();
}
