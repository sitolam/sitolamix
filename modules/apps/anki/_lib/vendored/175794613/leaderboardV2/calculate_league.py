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
from aqt import mw

from ..config_manager import write_config

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from .build_bord_v2 import RebuildLeaderbord

class CalculateLeague:
    def __init__(self, rebuild:"RebuildLeaderbord", response):

        self.rebuild = rebuild
        self.rebuild.user_rank_league = None

        self.response = response

        self.alpha_ranking = []
        self.beta_ranking = []
        self.gamma_ranking = []
        self.delta_ranking = []

        self.alpha_count = 0
        self.beta_count = 0
        self.gamma_count = 0
        self.delta_count = 0

        self.alpha_cache = []
        self.beta_cache = []
        self.gamma_cache = []
        self.delta_cache = []

        self.user_league_name = "Delta"
        self.medal_users = []

        self.config = mw.addonManager.getConfig(__name__)

        self.calculate_league()

    def add_medals(self, username, history):
        if history:
            history = json.loads(history)
            if self.config["show_medals"] == True:
                if history["gold"] != 0 or history["silver"] != 0 or history["bronze"] != 0:
                    self.medal_users.append([username, history["gold"], history["silver"], history["bronze"]])
                    username = f"{username} |"
                if history["gold"] > 0:
                    username = f"{username} {history['gold'] if history['gold'] != 1 else ''}🥇"
                if history["silver"] > 0:
                    username = f"{username} {history['silver'] if history['silver'] != 1 else ''}🥈"
                if history["bronze"] > 0:
                    username = f"{username} {history['bronze'] if history['bronze'] != 1 else ''}🥉"
        return username

    def save_user_rank(self, username:str, rank_number):
        if username.split(" |")[0] == self.config["username"]:
            self.rebuild.user_rank_league = rank_number

    def calculate_league(self):

        self.medal_users = []

        for item in self.response[1]:
            username = item[0]
            xp = item[1]
            time_spend = item[2]
            reviews = item[3]
            retention = item[4]
            league_name = item[5]
            history = item[6]
            days_learned = item[7]

            if self.config["username"] == username:
                self.user_league_name = league_name

            if history:
                username = self.add_medals(username, history)

            if xp != 0:
                # username = self.add_medals(username, history)
                if league_name == "Alpha":
                        self.alpha_count += 1
                        self.alpha_ranking.append((item, self.alpha_count))
                        self.alpha_cache.append([username, xp, time_spend, reviews, retention, days_learned, self.alpha_count, None])
                        self.save_user_rank(username, self.alpha_count)

                elif league_name == "Beta":
                        self.beta_count += 1
                        self.beta_ranking.append((item, self.beta_count))
                        self.beta_cache.append([username, xp, time_spend, reviews, retention, days_learned, self.beta_count, None])
                        self.save_user_rank(username, self.beta_count)

                elif league_name == "Gamma":
                        self.gamma_count += 1
                        self.gamma_ranking.append((item, self.gamma_count))
                        self.gamma_cache.append([username, xp, time_spend, reviews, retention, days_learned, self.gamma_count, None])
                        self.save_user_rank(username, self.gamma_count)

                elif league_name == "Delta":
                        self.delta_count += 1
                        self.delta_ranking.append((item, self.delta_count))
                        self.delta_cache.append([username, xp, time_spend, reviews, retention, days_learned, self.delta_count, None])
                        self.save_user_rank(username, self.delta_count)

        write_config("medal_users", self.medal_users)



        #📍
        # write_config("medal_users", medal_users)

    def get_cache(self, league_name="Delta"):
        if league_name == "Alpha":
            return self.alpha_cache
        elif league_name == "Beta":
            return self.beta_cache
        elif league_name == "Gamma":
            return self.gamma_cache
        elif league_name == "Delta":
            return self.delta_cache
        else:
            return []


    def get_user_item_and_rank(self, user_name):
        for ranking in [self.alpha_ranking, self.beta_ranking, self.gamma_ranking, self.delta_ranking]:
            for item, count in ranking:
                if user_name == item[0]:
                    league_name = item[5]
                    if league_name == "Alpha":
                        total_number = self.alpha_count
                    elif league_name == "Beta":
                        total_number = self.beta_count
                    elif league_name == "Gamma":
                        total_number = self.gamma_count
                    else:
                        total_number = self.delta_count
                    return count, total_number
        return 0, self.delta_count


    def get_ranking_by_league(self, league_name):
        if league_name == "Alpha":
            return self.alpha_ranking
        elif league_name == "Beta":
            return self.beta_ranking
        elif league_name == "Gamma":
            return self.gamma_ranking
        else:
            return self.delta_ranking

    def compute_user_rank_by_name(self, user_name):
        number, total_users = self.get_user_item_and_rank(user_name)
        return compute_user_rank(number, total_users)


def compute_user_rank(number, total_users):

    number = max(1, min(number, total_users))

    top_or_buttom_20_per = int((total_users / 100) * 20)
    top_80_per = total_users - top_or_buttom_20_per

    ranks = {
        10: [10, "A+", "(Top 10%)"],
        20: [20, "A", "(Top 10-20%)"],
        30: [30, "B+", "(Top 20-30%)"],
        40: [40, "B", "(Mid 30-40%)"],
        50: [50, "C+", "(Mid 40-50%)"],
        60: [60, "C", "(Mid 50-60%)"],
        70: [70, "D+", "(Lower 60-70%)"],
        80: [80, "D", "(Lower 70-80%)"],
        90: [90, "E", "(Bottom 80-90%)"],
        100: [100, "F", "(Bottom 90-100%)"]
    }

    if total_users <= 10 and number <= 10:
        return ranks[number * 10]

    # Top 20%
    if number <= top_or_buttom_20_per:
        if number > (top_or_buttom_20_per // 2):
            return ranks[20]
        else:
            return ranks[10]

    top_30_to_80 = total_users - (top_or_buttom_20_per)*2

    # Top 30% - 80%
    if number <= top_80_per:
        if number <= top_or_buttom_20_per + (top_30_to_80 // 6):
            return ranks[30]
        elif number <= top_or_buttom_20_per + (top_30_to_80 // 6) * 2:
            return ranks[40]
        elif number <= top_or_buttom_20_per + (top_30_to_80 // 6) * 3:
            return ranks[50]
        elif number <= top_or_buttom_20_per + (top_30_to_80 // 6) * 4:
            return ranks[60]
        elif number <= top_or_buttom_20_per + (top_30_to_80 // 6) * 5:
            return ranks[70]
        else:
            return ranks[80]

    # Bottom 20%
    if number > top_80_per:
        if number > (total_users - (top_or_buttom_20_per // 2)):
            return ranks[100]
        else:
            return ranks[90]

    return ranks[50] # default: something error
