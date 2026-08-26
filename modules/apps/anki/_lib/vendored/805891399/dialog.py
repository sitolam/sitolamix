from aqt import mw
from aqt.qt import (
    QDialog,
    QDialogButtonBox,
    QKeySequence,
    QMetaObject,
    QShortcut,
    Qt,
    QVBoxLayout
)
from aqt.utils import (
     askUser,
     saveGeom,
     restoreGeom,
)
from .anki_version_detection import anki_point_version
from .helpers import post_process_html
from .my_webview import MyWebView
from .vars import cssfiles, other_jsfiles


class ExtraWysiwygEditorForField(QDialog):
    def __init__(
        self,
        editor,
        bodyhtml,
        js_file,
        js_save_command,
        wintitle,
        dialogname,
        content_surrounded_with_div,
        web_path,
    ):
        # editor.widget is self.form.fieldsArea which is a QWidget
        super(ExtraWysiwygEditorForField, self).__init__(editor.widget)

        if anki_point_version <= 44:
            mw.setupDialogGC(self)
        else:
            mw.garbage_collect_on_dialog_finish(self)

        self.js_file = js_file
        self.content_surrounded_with_div = content_surrounded_with_div
        self.web_path = web_path
        self.js_save_command = js_save_command
        self.editor = editor
        self.parent = editor.parentWindow
        self.setWindowTitle(wintitle)
        self.resize(810, 700)
        restoreGeom(self, "805891399_winsize")

        main_layout = QVBoxLayout()
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        self.setLayout(main_layout)
        self.web = MyWebView(self, self.web_path, self.js_file)
        self.web.allowDrops = True  # default in webview/AnkiWebView is False
        self.web.title = dialogname
        self.web.contextMenuEvent = self.contextMenuEvent
        main_layout.addWidget(self.web)

        self.buttonBox = QDialogButtonBox(self)
        self.buttonBox.setOrientation(Qt.Orientation.Horizontal)
        self.buttonBox.setStandardButtons(
            QDialogButtonBox.StandardButton.Cancel
            | QDialogButtonBox.StandardButton.Save
        )
        main_layout.addWidget(self.buttonBox)

        self.buttonBox.accepted.connect(self.onAccept)
        self.buttonBox.rejected.connect(self.onReject)
        QMetaObject.connectSlotsByName(self)
        accept_shortcut = QShortcut(QKeySequence("Ctrl+Return"), self)
        accept_shortcut.activated.connect(self.onAccept)

        zoom_in_shortcut = QShortcut(QKeySequence("Ctrl++"), self)
        zoom_in_shortcut.activated.connect(self.web.zoom_in)

        zoom_out_shortcut = QShortcut(QKeySequence("Ctrl+-"), self)
        zoom_out_shortcut.activated.connect(self.web.zoom_out)

        self.web.stdHtml(
            body=bodyhtml,
            css=cssfiles,
            js=[self.js_file] + other_jsfiles,
            head="",
            context=self,
        )

    def onAccept(self):
        js_editor_out = self.web.sync_execJavaScript(self.js_save_command)
        self.editor.edited_field_content = post_process_html(
            js_editor_out, self.content_surrounded_with_div
        )
        self.web = None
        # self.web._page.windowCloseRequested()  # native qt signal not callable
        # self.web._page.windowCloseRequested.connect(self.web._page.window_close_requested)
        saveGeom(self, "805891399_winsize")
        self.accept()
        # self.done(0)

    def onReject(self):
        ok = askUser("Close and lose current input?")
        if ok:
            saveGeom(self, "805891399_winsize")
            self.web = None
            self.reject()

    def closeEvent(self, event):
        ok = askUser("Close and lose current input?")
        if ok:
            self.web = None
            event.accept()
        else:
            event.ignore()
