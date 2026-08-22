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


from aqt import QPushButton, QHBoxLayout, QSizePolicy, QLabel

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from .leaderboardV2 import PaginationBoard

class FriendBoard():
    def __init__(self, table_widget: "PaginationBoard"):
        self.table_widget = table_widget
        search_friend_button = self.add_friend_search_button()
        table_widget.custom_layout.addWidget(search_friend_button)
        table_widget.custom_layout.addStretch()

    ### Search Friends ###
    def run_serach_users_window(self):
        from ..config_search_friends import SearchFriendWindow
        search_window = SearchFriendWindow(self.table_widget)
        search_window.exec()

    def add_friend_search_button(self):
        search_friend_button = QPushButton()
        search_friend_button.setAutoDefault(False)
        search_friend_button.setObjectName("Search Users")
        search_friend_button.setText("Search Users")
        search_friend_button.clicked.connect(self.run_serach_users_window)

        size_policy = QSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        search_friend_button.setSizePolicy(size_policy)

        return search_friend_button
