from aqt.qt import (
    QDialog,
    QDialogButtonBox,
    QPlainTextEdit,
    QPushButton,
    Qt,
    QVBoxLayout,
)
from aqt.utils import (
    restoreGeom,
    saveGeom,
)

class Text_Displayer(QDialog):
    def __init__(self, parent, text, windowtitle, dialogname_for_restore=None):
        QDialog.__init__(self, parent, Qt.WindowType.Window)
        self.parent = parent
        self.text = text
        self.windowtitle = windowtitle
        self.dialogname_for_restore = dialogname_for_restore
        self.setup_window()
        self.pte.setPlainText(self.text)
        self.pte.setReadOnly(True)

    def setup_window(self):
        self.setWindowTitle(self.windowtitle)
        self.vbox = QVBoxLayout()
        self.vbox.setContentsMargins(0, 0, 0, 0)
        self.pte = QPlainTextEdit()
        self.vbox.addWidget(self.pte)
        self.bbox = QDialogButtonBox()

        self.closeButton = QPushButton("Close")
        self.closeButton.setAutoDefault(False)
        self.bbox.addButton(self.closeButton, QDialogButtonBox.ButtonRole.RejectRole)
        self.closeButton.clicked.connect(self.reject)

        self.vbox.addWidget(self.bbox)
        self.setLayout(self.vbox)
        self.resize(800, 600)
        if self.dialogname_for_restore:
            restoreGeom(self, self.dialogname_for_restore)

    def reject(self):
        if self.dialogname_for_restore:
            saveGeom(self, self.dialogname_for_restore)
        QDialog.reject(self)

    def accept(self):
        self.text = self.pte.toPlainText()
        if self.dialogname_for_restore:
            saveGeom(self, self.dialogname_for_restore)
        QDialog.accept(self)
