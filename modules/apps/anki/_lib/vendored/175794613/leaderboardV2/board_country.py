# Anki Leaderboard
# Copyright (C) 2020 - 2024 Thore Tyborski <https://github.com/ThoreBor>
# Copyright (C) 2024 Shigeyuki <http://patreon.com/Shigeyuki>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


from aqt import QIcon, Qt, QPushButton, QHBoxLayout, QSizePolicy, QLabel
from aqt import mw
from aqt.utils import openLink

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from .leaderboardV2 import PaginationBoard

from ..custom_shige.country_dict import COUNTRY_LIST_V2
from ..custom_shige.path_manager import DISCORD_ICON, DISCORD_INVITE_URL

def mini_button(button:QPushButton):
    button.setStyleSheet("QPushButton { padding: 2px 10px; }")
    button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
    button.setFocusPolicy(Qt.FocusPolicy.NoFocus)

class CountryBoard():
    def __init__(self, table_widget: "PaginationBoard"):
        self.table_widget = table_widget
        search_friend_button = self.add_country_button()
        if search_friend_button:
            table_widget.custom_layout.addWidget(search_friend_button)

        table_widget.custom_layout.addStretch()

    ### Search Country ###
    def run_set_country_window(self):
        from ..config_set_country import SetCountryWindow
        country_window = SetCountryWindow(self.table_widget)
        country_window.exec()

    def add_country_button(self):
        config = mw.addonManager.getConfig(__name__)
        country = config.get("country", "Country") # type:str

        search_country_button = None
        if not country.replace(" ", "") in COUNTRY_LIST_V2.keys():
            country = "Country"

            search_country_button = QPushButton(self.table_widget)
            search_country_button.setText("Select your Country")
            search_country_button.clicked.connect(self.run_set_country_window)
            mini_button(search_country_button)

        return search_country_button
