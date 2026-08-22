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


from aqt import mw
from aqt import QSize, QIcon, QTableWidget

def change_icon_size(q_icon:QIcon, column_number):
    config = mw.addonManager.getConfig(__name__)
    size_multiplier = config.get("size_multiplier", 1.2)
    new_row_size = int( 30 * size_multiplier)
    # if column_number == 7:
    if not column_number in [8, 6]:
        size_half = 1
    else:
        size_half = 0.5
    icon_size = QSize(int(new_row_size * size_half), int(new_row_size * size_half))
    resized_icon = QIcon(q_icon.pixmap(icon_size))
    return resized_icon