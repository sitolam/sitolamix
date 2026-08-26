# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import os

from aqt import mw
from aqt.utils import openLink

try:
    from PyQt6.QtCore import Qt, QTimer
    from PyQt6.QtWidgets import (
        QApplication, QVBoxLayout, QPushButton, QFileDialog, QMessageBox, QLabel,
        QDialog, QMenu, QVBoxLayout, QDialogButtonBox, QHBoxLayout)
    from PyQt6.QtGui import QPixmap, QImage, QPainter, QBrush, QContextMenuEvent, QAction, QIcon
except:
    from aqt.qt import Qt, QTimer
    from aqt.qt import (
        QApplication, QVBoxLayout, QPushButton, QFileDialog, QMessageBox, QLabel,
        QDialog, QMenu, QVBoxLayout, QDialogButtonBox, QHBoxLayout)
    from aqt.qt import QPixmap, QImage, QPainter, QBrush, QContextMenuEvent, QAction, QIcon

from .api_constants import UPLOAD_ICON_TIMEOUT
from .path_manager import ADDON_NAME

# from ...custom_shige.path_manager import POST_REQUEST
POST_REQUEST = "https://shigeyuki.pythonanywhere.com/shige_api/upload_image/"
# POST_REQUEST = 'http://127.0.0.1:8000/upload_image/'

IMAGE_SIZE = 64

class ImageUploader(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.initUI()

    def initUI(self):
        layout = QVBoxLayout()

        addon_path = os.path.dirname(__file__)
        settings_icon = QIcon(os.path.join(addon_path, "shige_pop", "popup_icon.png"))
        self.setWindowIcon(settings_icon)


        self.setWindowTitle('Leaderboard Profile Icon Uploader by Shige')

        self.default_text = "<br><br>Upload your image from the button<br> or right-click and paste it here.<br><br>"
        self.text_label= QLabel(self.default_text)
        # self.text_label.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)

        layout.addWidget(self.text_label)

        hbox = QHBoxLayout()

        self.uploadButton = QPushButton('📤Upload Image', self)
        self.uploadButton.clicked.connect(self.upload_image)
        hbox.addWidget(self.uploadButton)

        self.wikiButton = QPushButton('📖How to use', self)
        self.wikiButton.clicked.connect(
            lambda: openLink(
                "https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html#profile-icon"))
        hbox.addWidget(self.wikiButton)

        self.closeButton = QPushButton('Close', self)
        self.closeButton.clicked.connect(self.close)
        hbox.addWidget(self.closeButton)

        layout.addLayout(hbox)

        self.setLayout(layout)

        self.show()


    def upload_image(self):
        filePath, _ = QFileDialog.getOpenFileName(
            self, "Select Image", "", "Images (*.png *.jpg *.jpeg *.bmp *.gif)")
        if filePath:
            edited_image = self.edit_image(filePath)
            self.show_image(edited_image)


    def edit_image(self, image_or_filePath):
        if not isinstance(image_or_filePath, QImage):
            image = QImage(image_or_filePath)
        else:
            image = image_or_filePath

        image = image.scaled(IMAGE_SIZE, IMAGE_SIZE, Qt.AspectRatioMode.KeepAspectRatioByExpanding, Qt.TransformationMode.SmoothTransformation)
        rect = image.rect()
        x = (rect.width() - IMAGE_SIZE) // 2
        y = (rect.height() - IMAGE_SIZE) // 2
        image = image.copy(x, y, IMAGE_SIZE, IMAGE_SIZE)

        # Create a circular mask
        size = min(image.width(), image.height())
        mask = QImage(size, size, QImage.Format.Format_ARGB32)
        mask.fill(Qt.GlobalColor.transparent)

        painter = QPainter(mask)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setBrush(QBrush(Qt.GlobalColor.black))
        painter.drawEllipse(0, 0, size, size)
        painter.end()

        # Apply the mask to the image
        result = QImage(size, size, QImage.Format.Format_ARGB32)
        result.fill(Qt.GlobalColor.transparent)

        painter = QPainter(result)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.drawImage(0, 0, image)
        painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_DestinationIn)
        painter.drawImage(0, 0, mask)
        painter.end()

        return result

    def show_image(self, image):
        dialog = QDialog(self)
        dialog.setWindowTitle("Edited Image")

        layout = QVBoxLayout()
        label = QLabel()
        pixmap = QPixmap.fromImage(image)
        label.setPixmap(pixmap)
        layout.addWidget(label)

        buttonBox = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Close)
        buttonBox.accepted.connect(lambda: self.upload_edited_image(image))
        buttonBox.rejected.connect(dialog.reject)
        layout.addWidget(buttonBox)

        dialog.setLayout(layout)
        dialog.exec()

    def upload_edited_image(self, image:QImage):
        config = mw.addonManager.getConfig(__name__)
        data = {"username": config["username"], "authToken": config["authToken"]}

        addon_path = os.path.dirname(__file__)
        temp_path = os.path.join(addon_path, "temp_image.png")
        image.save(temp_path)

        from .api_connect import get_requests_session
        req_session = get_requests_session()

        with open(temp_path, 'rb') as file:
            url = f"{POST_REQUEST}"
            files = {'image': file}

            response = req_session.post(url, files=files, data=data, timeout=UPLOAD_ICON_TIMEOUT)

        try:
            from .custom_shige.shige_debug_tools import print_debug_data
            print_debug_data(response)
        except Exception as e:
            print(f"[{ADDON_NAME}] {e}")

        self.show_message(response.text)

        os.remove(temp_path)

    def contextMenuEvent(self, event: QContextMenuEvent):
        contextMenu = QMenu(self)
        pasteAction = QAction('Paste', self)
        pasteAction.triggered.connect(self.paste_image_from_clipboard)
        contextMenu.addAction(pasteAction)
        contextMenu.exec(event.globalPos())

    def paste_image_from_clipboard(self):
        clipboard = QApplication.clipboard()
        mimeData = clipboard.mimeData()
        if mimeData.hasImage():
            image = clipboard.image()
            edited_image = self.edit_image(image)
            self.show_image(edited_image)
        else:
            self.text_label.setText("Hummm, no image in clipboard :-/")
            QTimer.singleShot(5000, lambda: self.text_label.setText(self.default_text))


    def show_message(self, message):
        msg_box = QMessageBox()
        msg_box.setIcon(QMessageBox.Icon.Information)
        msg_box.setText(message)
        msg_box.setWindowTitle("Upload Result")
        msg_box.exec()



def upload_image_request():
    if hasattr(mw, 'shige_leaderboard_image_uploader') and isinstance(mw.shige_leaderboard_image_uploader, ImageUploader):
        mw.shige_leaderboard_image_uploader.show()
        mw.shige_leaderboard_image_uploader.raise_()
    else:
        mw.shige_leaderboard_image_uploader = ImageUploader(mw)

