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


from aqt import mw, QTableWidget

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .build_bord_v2 import RebuildLeaderbord

### mini mode ###
def set_mini_mode(rebuildboard:"RebuildLeaderbord", table_widget:"QTableWidget"):
    config = mw.addonManager.getConfig(__name__)
    is_mini_mode = config.get("mini_mode", False)
    if not is_mini_mode:
        return

    is_league = False
    if table_widget == rebuildboard.League_Leaderboard:
        is_league = True

    for column_index in range(2, 7):
        header_item = table_widget.horizontalHeaderItem(column_index)
        if header_item:
            text = header_item.text()

            if column_index == 1:
                if is_league:
                    text = "NAME"
                else:
                    text = "NAME"
            elif column_index == 2:
                if is_league:
                    text = "XP"
                else:
                    text = "REV"
            elif column_index == 3:
                if is_league:
                    text = "TIME"
                else:
                    text = "TIME"
            elif column_index == 4:
                if is_league:
                    text = "REV"
                else:
                    text = "STR"
            elif column_index == 5:
                if is_league:
                    text = "RE%"
                else:
                    text = "31D"
            elif column_index == 6:
                if is_league:
                    text = "ST%"
                else:
                    text = "RE%"
            header_item.setText(text)
