from .anki_version_detection import anki_point_version

if anki_point_version >= 50:
    from anki.utils import is_lin as isLin
else:
    from anki.utils import isLin

from aqt import mw
from aqt.qt import (
    QEvent,
    QWebEngineView,
    QNativeGestureEvent,
    Qt,
)
from aqt.webview import AnkiWebView

from .sync_execJavaScript import sync_execJavaScript
from .vars import (
    addon_cssfiles,
    other_jsfiles,
)


class MyWebView(AnkiWebView):
    def __init__(self, parent, web_path, editor_js_file):
        super().__init__(parent)
        self.web_path = web_path
        self.editor_js_file = editor_js_file

    def sync_execJavaScript(self, script):
        return sync_execJavaScript(self, script)

    def bundledScript(self, fname):
        if fname in [self.editor_js_file] + other_jsfiles:
            return '<script src="%s"></script>' % (self.web_path + fname)
        else:
            return '<script src="%s"></script>' % self.webBundlePath(fname)

    def bundledCSS(self, fname):
        if fname in addon_cssfiles:
            return '<link rel="stylesheet" type="text/css" href="%s">' % (
                self.web_path + fname
            )
        else:
            return (
                '<link rel="stylesheet" type="text/css" href="%s">'
                % self.webBundlePath(fname)
            )

    def zoom_in(self):
        self.change_zoom_by(1.1)

    def zoom_out(self):
        self.change_zoom_by(1 / 1.1)

    def change_zoom_by(self, interval):
        currZoom = QWebEngineView.zoomFactor(self)
        self.setZoomFactor(currZoom * interval)

    def wheelEvent(self, event):
        # doesn't work in 2020-05?
        pass

    def eventFilter(self, obj, evt):
        # from aqt.webview.AnkiWebView
        #    because wheelEventdoesn't work in 2020-05?

        # disable pinch to zoom gesture
        if isinstance(evt, QNativeGestureEvent):
            return True

        ###my mod
        # event type 31  # https://doc.qt.io/qt-5/qevent.html
        # evt.angleDelta().x() == 0   =>  ignore sidecroll
        elif (
            evt.type() == QEvent.Type.Wheel
            and evt.angleDelta().x() == 0
            and (mw.app.keyboardModifiers() & Qt.KeyboardModifier.ControlModifier)
        ):
            dif = evt.angleDelta().y()
            if dif > 0:
                self.zoom_out()
            else:
                self.zoom_in()
        ### end my mode

        elif evt.type() == QEvent.Type.MouseButtonRelease:
            if evt.button() == Qt.MouseButton.MiddleButton and isLin:
                self.onMiddleClickPaste()
                return True
            return False
        return False
