
from aqt import QWidget, QMouseEvent, QFrame, QPalette, QColor, Qt, QPoint, QLabel, QTimer
import aqt
from aqt.theme import theme_manager

_tooltipTimer: QTimer = None
_shigeToolTipLabel: QLabel= None

# closeTooltipで閉じるのを避ける
def shigeToolTip(
    msg: str,
    period: int = 3000,
    parent: QWidget = None,
    x_offset: int = 0,
    y_offset: int = 100,
) -> None:
    global _tooltipTimer, _shigeToolTipLabel

    class CustomLabel(QLabel):
        silentlyClose = True

        def mousePressEvent(self, evt: QMouseEvent) -> None:
            evt.accept()
            self.hide()

    closeTooltip()
    aw = parent or aqt.mw.app.activeWindow() or aqt.mw
    lab = CustomLabel(
        f"""<table cellpadding=10>
<tr>
<td>{msg}</td>
</tr>
</table>""",
        aw,
    )
    lab.setFrameStyle(QFrame.Shape.Panel)
    lab.setLineWidth(2)
    lab.setWindowFlags(Qt.WindowType.ToolTip)
    if not theme_manager.night_mode:
        p = QPalette()
        p.setColor(QPalette.ColorRole.Window, QColor("#feffc4"))
        p.setColor(QPalette.ColorRole.WindowText, QColor("#000000"))
        lab.setPalette(p)
    lab.move(aw.mapToGlobal(QPoint(0 + x_offset, aw.height() - y_offset)))
    lab.show()
    _tooltipTimer = aqt.mw.progress.timer(
        period, closeTooltip, False, requiresCollection=False, parent=aw
    )
    _shigeToolTipLabel = lab


def closeTooltip() -> None:
    global _shigeToolTipLabel, _tooltipTimer
    if _shigeToolTipLabel:
        try:
            _shigeToolTipLabel.deleteLater()
        except RuntimeError:
            # already deleted as parent window closed
            pass
        _shigeToolTipLabel = None
    if _tooltipTimer:
        try:
            _tooltipTimer.deleteLater()
        except RuntimeError:
            pass
        _tooltipTimer = None