
HIDE_ALL_USERS_NAME = False
SHOW_YOUR_NAME = False

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .Leaderboard import start_main

from aqt import mw
from aqt.qt import QIcon, QTableWidget, QPixmap, QPainter, QImage, Qt

def hide_all_users_name(self:"start_main"):
    config = mw.addonManager.getConfig(__name__)
    hide_all_users_name = config.get("hide_all_users_name", False)
    show_your_name = config.get("show_your_name", False)

    if not hide_all_users_name:
        return

    leader_boards = [
        self.dialog.Global_Leaderboard,
        self.dialog.Friends_Leaderboard,
        self.dialog.Country_Leaderboard,
        self.dialog.Custom_Leaderboard,
        self.dialog.League,
    ]

    for leaderboard in leader_boards:
        leaderboard : QTableWidget
        row_count = leaderboard.rowCount()
        column_count = leaderboard.columnCount()
        for row in range(row_count):
            item = leaderboard.item(row, 1)

            if show_your_name:
                if self.config["username"] == item.text().split(" |")[0]:
                    continue

            user_name = item.text().split(" |")[0]
            if item:
                original_text = item.text()
                # masked_text = '*' * len(original_text)

                masked_name = f"UserName{row+1}"
                if " |" in original_text:
                    rest_of_text = original_text[len(user_name):]
                    masked_text = masked_name + rest_of_text
                else:
                    masked_text = masked_name

                item.setText(masked_text)
                if not item.icon().isNull():
                    icon = item.icon()
                    pixmap = icon.pixmap(64, 64)
                    image = pixmap.toImage()
                    blurred_image = blur_image(image, 100)
                    blurred_pixmap = QPixmap.fromImage(blurred_image)
                    item.setIcon(QIcon(blurred_pixmap))
                    # item.setIcon(QIcon())

                for col in range(column_count):
                    col_item = leaderboard.item(row, col)
                    if col_item:
                        tooltip_text = col_item.toolTip()
                        new_tooltip_text = tooltip_text.replace(user_name, masked_text)
                        col_item.setToolTip(new_tooltip_text)


def blur_image(image: QImage, radius: int) -> QImage:
    blurred = QImage(image.size(), QImage.Format.Format_ARGB32)
    blurred.fill(Qt.GlobalColor.transparent)
    painter = QPainter(blurred)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)
    painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
    painter.drawImage(0, 0, image)
    painter.end()

    for i in range(radius):
        blurred = blurred.scaled(blurred.width() // 2, blurred.height() // 2, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
        blurred = blurred.scaled(blurred.width() * 2, blurred.height() * 2, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)

    return blurred