# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

from aqt import mw
from aqt.utils import tooltip

try:
    from PyQt6.QtWidgets import QHBoxLayout, QComboBox, QLabel, QPushButton
    from PyQt6.QtCore import Qt
except:
    from aqt.qt import QHBoxLayout, QComboBox, QLabel, QPushButton
    from aqt.qt import Qt

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from .leaderboardV2 import RebuildLeaderbord, PaginationBoard



#MARK:SORT:
### sort by ###
def create_sortby_combobox(custom_layout:"QHBoxLayout"):
    sort_by_box = QComboBox()
    sort_by_box.setToolTip("Sort by...")
    sort_options = ["Reviews", "Time", "Streak", "31days", "Retention"]
    sort_by_box.addItems(sort_options)
    config = mw.addonManager.getConfig(__name__)
    current_sort = config.get("sortby", "Cards")

    if current_sort == "Cards":
        sort_by_box.setCurrentText("Reviews")
    elif current_sort == "Time_Spend":
        sort_by_box.setCurrentText("Time")
    elif current_sort == "Month":
        sort_by_box.setCurrentText("31days")
    elif current_sort in ["Streak", "Retention"]:
        sort_by_box.setCurrentText(current_sort)

    sort_by_box.currentTextChanged.connect(lambda: setSortby(sort_by_box))
    sort_by_box.setFocusPolicy(Qt.FocusPolicy.NoFocus)
    sort_label = QLabel("SORT:")
    sort_label.setStyleSheet("color: gray;")
    custom_layout.addWidget(sort_label)
    custom_layout.addWidget(sort_by_box)

def setSortby(sort_by_box:"QComboBox"):
    from ..config import write_config
    config = mw.addonManager.getConfig(__name__)
    sortby = sort_by_box.currentText()
    if sortby == "Reviews":
        write_config("sortby", "Cards")
    if sortby == "Time":
        write_config("sortby", "Time_Spend")
    if sortby == "Streak":
        write_config("sortby", sortby)
    if sortby == "31days":
        write_config("sortby", "Month")
    if sortby == "Retention":
        write_config("sortby", sortby)
    if config["homescreen"] == True:
        write_config("homescreen_data", [])
    tooltip("Changes will apply after the next sync!")




#MARK:MINI
def add_mini_mode_button(rebuild:"RebuildLeaderbord", table_widget: "PaginationBoard"):
    from ..shige_pop.button_manager import mini_button_v3
    mini_mode_button = QPushButton("Mini")
    mini_button_v3(mini_mode_button)

    mini_mode_button.clicked.connect(
        lambda:mini_mode_clicked(rebuild, table_widget))
    table_widget.pagination_layout.addWidget(mini_mode_button)

def mini_mode_clicked(rebuild:"RebuildLeaderbord", table_widget: "PaginationBoard"):
    from ..config import write_config
    current_setting = rebuild.config.get("mini_mode", False)
    new_setting = not current_setting

    write_config("mini_mode", new_setting)

    rebuild.reload_leaderboard(mini_mode=True)

    if new_setting:
        tooltip("Enabled", parent=table_widget)
    else:
        tooltip("Disabled", parent=table_widget)