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


from aqt import QComboBox, Qt, QHBoxLayout
from ..create_icon import create_leaderboard_icon

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .leaderboardV2 import RebuildLeaderbord, PaginationBoard

LEAGUE_NAMES = ["Alpha", "Beta", "Gamma", "Delta"]

def set_toggle_league(rebuild: "RebuildLeaderbord", table_widget:"PaginationBoard", user_league):

    toggle_leagues = QComboBox(table_widget)
    toggle_leagues.setObjectName("toggle_leagues")

    table_widget.custom_layout.addWidget(toggle_leagues)
    # table_widget.custom_layout.addStretch()

    def switch_league(index):
        if index is None:
            index = toggle_leagues.currentIndex()
        league_name = toggle_leagues.itemData(index)
        rebuild.league_cache = rebuild.calculate_league.get_cache(league_name)
        rebuild.current_league_name = league_name
        table_widget.resetPagination(rebuild.league_cache, rebuild.page_size)
        table_widget.goToFirstPage()

        from .discord_button import add_discord_button_toggle
        add_discord_button_toggle(table_widget.custom_layout, league_name)


    league_icons = {
    "Delta": "delta_12.png",
    "Gamma": "gamma_12.png",
    "Beta": "beta_12.png",
    "Alpha": "alpha_12.png",
    }

    league_stars = {
    "Delta": "★",
    "Gamma": "★★",
    "Beta": "★★★",
    "Alpha": "★★★★",
    }

    for item in range(0, len(LEAGUE_NAMES)):
        league_name = LEAGUE_NAMES[item]

        stars = league_stars.get(league_name, "★")
        display_name = f"{league_name} {stars}"

        league_icon_filename = league_icons.get(league_name, "delta_12.png")
        league_icon = create_leaderboard_icon(file_name=league_icon_filename, icon_type="shield")
        toggle_leagues.addItem(league_icon, display_name, league_name)

    index = toggle_leagues.findData(user_league)
    if index != -1:
        toggle_leagues.setCurrentIndex(index)

    try:
        if user_league:
            from .discord_button import add_discord_button_toggle
            add_discord_button_toggle(table_widget.custom_layout, user_league)
    except:
        pass

    toggle_leagues.currentIndexChanged.connect(switch_league)

