#pragma once

#include <QSplitter>
#include <memory>
#include <vector>

#include "control/controlobject.h"
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

  private slots:
    void slotSplitterMoved();
    void slotControlValueChanged(double value);

  private:
    void createControls(const QString& controlKeyPrefix);
    void updateControls();

    UserSettingsPointer m_pConfig;
    ConfigKey m_configKey;
    std::vector<std::unique_ptr<ControlObject>> m_paneControls;
};
