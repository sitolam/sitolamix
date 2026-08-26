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

import json
import datetime
import os

from .config_manager import write_config

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from .Leaderboard import start_main

from .rebuild_league import rebuild_league_table

def load_league(self: "start_main"):
    for i in self.response[1]:
        if self.config["username"] in i:
            self.user_league_name = i[5]
            # self.dialog.league_label.setText(f"{user_league_name}: {self.current_season}")
            self.dialog.league_label.setText(f"{self.current_season}")

    time_remaining = self.season_end - datetime.datetime.now()
    tr_days = time_remaining.days

    if tr_days < 0:
        self.dialog.time_left.setText(f"The next season is going to start soon.")
    else:
        self.dialog.time_left.setText(f"{tr_days} days remaining")
    self.dialog.time_left.setToolTip(f"Season start: {self.season_start} \nSeason end: {self.season_end} (local time)")

    ### BUILD TABLE ###

    medal_users = []
    for i in self.response[1]:
        username = i[0]
        league_name = i[5]

        self.save_all_users_ranking.save_user_rank(i)

        if i[6]:
            if self.config["show_medals"] == True:
                history = json.loads(i[6])
                if history["gold"] != 0 or history["silver"] != 0 or history["bronze"] != 0:
                    medal_users.append([username, history["gold"], history["silver"], history["bronze"]])
                    username = f"{username} |"
                if history["gold"] > 0:
                    username = f"{username} {history['gold'] if history['gold'] != 1 else ''}🥇"
                if history["silver"] > 0:
                    username = f"{username} {history['silver'] if history['silver'] != 1 else ''}🥈"
                if history["bronze"] > 0:
                    username = f"{username} {history['bronze'] if history['bronze'] != 1 else ''}🥉"


    leagues = self.save_all_users_ranking.get_ranking_by_league(self.user_league_name)
    rebuild_league_table(self, leagues, self.user_league_name)

    write_config("medal_users", medal_users)
