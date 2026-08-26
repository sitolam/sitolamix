from aqt.qt import *
from aqt.utils import (
    saveGeom, 
    restoreGeom,
)

class CheckDialog(QDialog):
    def __init__(self, parent=None, valuedict=None, windowtitle="", text = ""):
        super().__init__(parent)
        if windowtitle:
            self.setWindowTitle(windowtitle)
        self.valuedict = valuedict
        self.text = text
        self.setupUI()
        restoreGeom(self, "1972239816_select_templates_dialog")

    def change_state(self, item):
        state = Qt.CheckState.Checked if item.checkState() == Qt.CheckState.Unchecked else Qt.CheckState.Unchecked
        return item.setCheckState(state)

    def setupUI(self):
        vlay = QVBoxLayout()
        label = QLabel(self.text)
        self.listWidget = QListWidget()
        self.listWidget.itemClicked.connect(lambda item: self.change_state(item))
        for k, v in self.valuedict.items():
            item = QListWidgetItem()
            item.setText(k)
            if v:
                item.setCheckState(Qt.CheckState.Checked)
            else:
                item.setCheckState(Qt.CheckState.Unchecked)
            self.listWidget.addItem(item)
        buttonbox = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttonbox.accepted.connect(self.onAccept)
        buttonbox.rejected.connect(self.onReject)
        vlay.addWidget(label)
        vlay.addWidget(self.listWidget)
        vlay.addWidget(buttonbox)
        self.setLayout(vlay)

    def onAccept(self):
        for i in range(self.listWidget.count()):
            text = self.listWidget.item(i).text()
            if self.listWidget.item(i).checkState():
                self.valuedict[text] = True
            else:
                self.valuedict[text] = False
        saveGeom(self, "1972239816_select_templates_dialog")
        self.accept()

    def onReject(self):
        saveGeom(self, "1972239816_select_templates_dialog")
        self.reject()
