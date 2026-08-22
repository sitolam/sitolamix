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

from aqt import QComboBox

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .leaderboardV2 import RebuildLeaderbord, PaginationBoard

def set_toggle_groups(rebuild: "RebuildLeaderbord", table_widget:"PaginationBoard"):

    toggle_groups = QComboBox(table_widget)
    toggle_groups.setObjectName("toggle_groups")

    table_widget.custom_layout.addWidget(toggle_groups)


    def switch_groups(index):
        if index is None:
            index = toggle_groups.currentIndex()
        league_name = toggle_groups.itemData(index)
        rebuild.groups_cache = rebuild.all_groups_cache.get(league_name, [])
        table_widget.resetPagination(rebuild.groups_cache, rebuild.page_size)
        table_widget.goToFirstPage()

        try:
            if league_name:
                from .discord_button import add_discord_button_toggle
                add_discord_button_toggle(table_widget.custom_layout, league_name)
        except:
            pass


    for user_group_names in rebuild.config["groups"]:
        user_group_names:str
        trim_group_name = user_group_names.replace(" ", "")
        toggle_groups.addItem(user_group_names, trim_group_name)

    current_group = rebuild.config.get("current_group", []) #type: str
    if current_group:
        current_group = current_group.replace(" ", "")

    index = toggle_groups.findData(current_group)
    if index != -1:
        toggle_groups.setCurrentIndex(index)

    toggle_groups.currentIndexChanged.connect(switch_groups)

    try:
        if current_group:
            from .discord_button import add_discord_button_toggle
            add_discord_button_toggle(table_widget.custom_layout, current_group)
    except:
        pass

    table_widget.custom_layout.addStretch()