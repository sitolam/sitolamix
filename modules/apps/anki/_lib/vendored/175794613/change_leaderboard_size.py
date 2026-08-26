# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

from aqt import QFont, mw, QSize, QTableWidget, QIcon, Qt

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from . import start_main

original_row_height = None
original_font_size = None

def change_board_size(self:"start_main", tab_widget: QTableWidget):
    global original_row_height, original_font_size
    config = mw.addonManager.getConfig(__name__)

    zoom_enable = config.get("zoom_enable", True)
    if not zoom_enable:
        return

    tab_widget.setShowGrid(False)
    size_multiplier = config.get("size_multiplier", 1.2)
    for i in range(tab_widget.rowCount()):
        if not original_row_height:
            original_row_height = tab_widget.rowHeight(i)
        new_row_size = int(original_row_height * size_multiplier)
        tab_widget.setRowHeight(i, new_row_size)

        icon_size = QSize(int(new_row_size * 0.8), int(new_row_size * 0.8))
        tab_widget.setIconSize(icon_size)
        for j in range(tab_widget.columnCount()):
            item = tab_widget.item(i, j)
            if item is not None:

                font = item.font()

                # if j == 1:
                #     font.setBold(True)

                if not j == 1:
                    item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)

                if j in [2, 3, 4, 5, 6]:
                    pass

                if not original_font_size:
                    original_font_size = font.pointSize()

                new_font_size = int(original_font_size * size_multiplier)
                if j == 1:
                    new_font_size = int(new_font_size * 1.2)
                    # font.setBold(True)
                font.setPointSize(new_font_size)

                font_family = config.get("set_font_family", None)
                if font_family:
                    font.setFamily(font_family)
                item.setFont(font)

                if j in [7, 8]:
                    size_half = 0.5
                    if config.get("add_pic_country_and_league", True) and config.get("gamification_mode", True):
                        item.setTextAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
                        if j == 7:
                            size_half = 1
                        else:
                            size_half = 0.5
                    icon_size = QSize(int(new_row_size * size_half), int(new_row_size * size_half))
                    icon = item.icon()
                    if not icon.isNull():
                        new_icon = QIcon(icon.pixmap(icon_size))
                        item.setIcon(new_icon)

            # tab_widget.horizontalHeader().setMinimumSectionSize(new_row_size)



def change_size_zero(self:"start_main", tab_widget: QTableWidget):
    global original_font_size
    config = mw.addonManager.getConfig(__name__)

    zoom_enable = config.get("zoom_enable", True)
    if not zoom_enable:
        return

    size_multiplier = config.get("size_multiplier", 1.2)
    for i in range(tab_widget.rowCount()):
        for j in range(tab_widget.columnCount()):
            item = tab_widget.item(i, j)
            if item is not None:
                if j == 0:
                    font = item.font()
                    item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    if not original_font_size:
                        original_font_size = font.pointSize()
                    new_font_size = int(original_font_size * size_multiplier)
                    font.setPointSize(new_font_size)
                    item.setFont(font)
