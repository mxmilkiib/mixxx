#pragma once

#include <QSplitter>

#include "preferences/usersettings.h"
#include "widget/wbasewidget.h"

class QDomNode;
class SkinContext;

class WSplitter : public QSplitter, public WBaseWidget {
    Q_OBJECT
  public:
    WSplitter(QWidget* pParent, UserSettingsPointer pConfig);

    void setup(const QDomNode& node, const SkinContext& context);

  protected:
    bool event(QEvent* pEvent) override;
    void mouseDoubleClickEvent(QMouseEvent* pEvent) override;

  private slots:
    void slotSplitterMoved();

  private:
    UserSettingsPointer m_pConfig;
    ConfigKey m_configKey;
    QList<int> m_savedSizes;
};
