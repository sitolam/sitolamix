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


from aqt import QTableWidget
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .build_bord_v2 import RebuildLeaderbord


### Rearrange Columns ###
def rearrange_columns(rebuild:"RebuildLeaderbord", table_widget:"QTableWidget"):
    # is_mini_mode = rebuild.config.get("mini_mode", False)
    # if is_mini_mode:
    #     return

    table_widget.horizontalHeader().setSectionsMovable(True)

    desired_order = [1, 2, 3, 4, 5, 6, 7, 0, 8]
    for index, target_index in enumerate(desired_order):
        now_index = table_widget.horizontalHeader().visualIndex(index)
        if now_index != target_index:
            table_widget.horizontalHeader().moveSection(now_index, target_index)

    table_widget.horizontalHeader().setSectionsMovable(False)



    # test_func = False
    # if test_func:
    #     def save_column_widths(table_widget:"QTableWidget"):
    #         column_widths = [table_widget.columnWidth(i) for i in range(tab_widget.columnCount())]
    #         write_config("column_widths", column_widths)

    #     def save_column_order(tab_widget:"QTableWidget"):
    #         column_order = [tab_widget.horizontalHeader().visualIndex(i) for i in range(tab_widget.columnCount())]
    #         write_config("desired_order", column_order)

    #     if table_widget == rebuildboard.Global_Leaderboard or is_league:
    #         table_widget.horizontalHeader().sectionMoved.connect(lambda: save_column_order(table_widget))
    #         table_widget.horizontalHeader().sectionResized.connect(lambda: save_column_widths(table_widget))