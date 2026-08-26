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
from datetime import date, timedelta
import os
from os.path import dirname, join, realpath

from aqt.operations import QueryOp
from aqt import  QAbstractItemView, QColor, QCursor, QFont, QHeaderView, QIcon, QSize, QTableWidget, QTableWidgetItem, Qt, mw

from .safe_qtimer import SafeQTimer

from aqt.utils import tooltip
from anki.utils import pointVersion

from ..config_manager import write_config
from .streaks_achievement import achievement
from .board_league import highlight_league

from ..Stats import Stats
from ..version import version
from ..userInfo import start_user_info
from ..api_connect import postRequest

from ..icon_downloader import IconDownloader
from ..custom_shige.path_manager import ONLINE_DOT
from ..custom_shige.country_dict import COUNTRY_LIST_V2

from ..custom_shige.count_time import shigeTaskTimer
from ..custom_shige.random_error import custom_error

from .calculate_league import CalculateLeague
from .custom_column import custom_column_size
from .mini_mode import set_mini_mode

from ..custom_shige.translate.translate import ShigeTranslator
_translate = ShigeTranslator.translate

from .custom_qtable_widget import QTableWidgetV2 as QTableWidget
from .rearrange_columns import rearrange_columns

from ..path_manager import ADDON_NAME


from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from .leaderboardV2 import PaginationBoard


class RebuildLeaderbord:
    def __init__(self):
        shigeTaskTimer.start("RebuildLeaderbord")
        self.cancel_execution = False

        self.global_cache = []
        self.friends_cache = []

        ## Country ##
        self.country_cache = []
        self.all_country_cache = {}
        self.each_country_counter = {}
        self.each_country_reviews = {}

        self.all_users_country_dict = {}

        ## Groups ###
        self.groups_cache = []
        self.all_groups_cache = {}
        self.each_group_counter = {}

        ## League ##
        self.league_cache = []
        self.current_league_name = "Delta"

        ## Within one month ##
        self.within_one_month_users = {}

        ## user ##
        self.user_score = []
        self.user_groups_name_list = []

        self.user_rank_global = 0
        self.user_rank_friends = 0
        self.user_rank_country = 0
        self.user_rank_groups = {}
        self.user_rank_league = 0

        self.total_rows = 0
        self.start_day = None
        self.page_size = 100 #📍

        self.previous_page = False

        self.config = mw.addonManager.getConfig(__name__)

        from .. import get_startup_shige_leaderboard
        self.startup = get_startup_shige_leaderboard()
        self.season_start = self.startup.start
        self.season_end = self.startup.end
        self.currentSeason = self.startup.currentSeason

        self.Global_Leaderboard = self.create_table_widget()
        self.Friends_Leaderboard = self.create_table_widget()
        self.Country_Leaderboard = self.create_table_widget()
        self.Custom_Leaderboard = self.create_table_widget()

        self.League_Leaderboard = self.create_table_widget(is_league=True)

        # try:
        #     from aqt.theme import theme_manager
        #     nightmode = theme_manager.night_mode
        # except: #for older versions
        #     try:
        #         nightmode = mw.pm.night_mode()
        #     except:
        #         nightmode = False
        #     nightmode = False

        # with open(join(dirname(dirname(realpath(__file__))), "colors.json"), "r") as colors_file:
        #     data = colors_file.read()
        # colors_themes = json.loads(data)
        # self.colors = colors_themes["dark"] if nightmode else colors_themes["light"]

        from ..colors_config import get_color_config
        self.colors = get_color_config()

        # if self.config.get("add_pic_country_and_league", True):
        if True:
            self.user_icons_downloader = IconDownloader(self)

        self.startSync()


    def reload_leaderboard(self, mini_mode=False):
        table_widgets = [
        self.pagination_board.global_page,
        self.pagination_board.friend_page,
        self.pagination_board.country_page,
        self.pagination_board.group_page,
        self.pagination_board.league_page]

        for table_widget in table_widgets:
            table_widget: "PaginationBoard"
            if mini_mode:
                set_mini_mode(self, table_widget.table_widget)
            self.set_table_widget_size(table_widget.table_widget)
            table_widget.reloadPage()


    def set_table_widget_size(self, table_widget:QTableWidget):
        size_multiplier = self.config.get("size_multiplier", 1.2)
        new_row_size = int( 30 * size_multiplier)
        table_widget.verticalHeader().setDefaultSectionSize(new_row_size)
        icon_size = QSize(int(new_row_size * 0.8), int(new_row_size * 0.8))
        table_widget.setIconSize(icon_size)

    def set_font_and_size_item(self, item:QTableWidgetItem):
        size_multiplier = self.config.get("size_multiplier", 1.2)
        font_family = self.config.get("set_font_family", None)
        new_font_size = int( 9  * size_multiplier)
        if font_family:
            current_font = QFont(font_family, new_font_size)
        else:
            current_font = item.font()
        current_font.setPointSize(new_font_size)
        item.setFont(current_font)

    def create_table_widget(self, is_league=None):
        table_widget = QTableWidget()
        table_widget.setShowGrid(False)
        table_widget.setSelectionMode(QTableWidget.SelectionMode.SingleSelection)
        table_widget.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)

        self.set_table_widget_size(table_widget)

        if self.config.get("gamification_mode", True):
            table_widget.setColumnCount(9)
        else:
            table_widget.setColumnCount(7)

        table_widget.setRowCount(0)

        item = QTableWidgetItem()
        item.setTextAlignment(Qt.AlignmentFlag.AlignCenter | Qt.AlignmentFlag.AlignVCenter)
        table_widget.setHorizontalHeaderItem(0, item)
        item = QTableWidgetItem()
        item.setTextAlignment(Qt.AlignmentFlag.AlignCenter | Qt.AlignmentFlag.AlignVCenter)
        table_widget.setHorizontalHeaderItem(1, item)
        item = QTableWidgetItem()
        item.setTextAlignment(Qt.AlignmentFlag.AlignCenter|Qt.AlignmentFlag.AlignVCenter)
        table_widget.setHorizontalHeaderItem(2, item)
        item = QTableWidgetItem()
        item.setTextAlignment(Qt.AlignmentFlag.AlignCenter | Qt.AlignmentFlag.AlignVCenter)
        table_widget.setHorizontalHeaderItem(3, item)
        item = QTableWidgetItem()
        item.setTextAlignment(Qt.AlignmentFlag.AlignCenter | Qt.AlignmentFlag.AlignVCenter)
        table_widget.setHorizontalHeaderItem(4, item)
        item = QTableWidgetItem()
        item.setTextAlignment(Qt.AlignmentFlag.AlignCenter | Qt.AlignmentFlag.AlignVCenter)
        table_widget.setHorizontalHeaderItem(5, item)
        item = QTableWidgetItem()
        item.setTextAlignment(Qt.AlignmentFlag.AlignCenter | Qt.AlignmentFlag.AlignVCenter)
        table_widget.setHorizontalHeaderItem(6, item)
        if self.config.get("gamification_mode", True):
            item = QTableWidgetItem()
            item.setTextAlignment(Qt.AlignmentFlag.AlignCenter | Qt.AlignmentFlag.AlignVCenter)
            table_widget.setHorizontalHeaderItem(7, item)
            item = QTableWidgetItem()
            item.setTextAlignment(Qt.AlignmentFlag.AlignCenter | Qt.AlignmentFlag.AlignVCenter)
            table_widget.setHorizontalHeaderItem(8, item)

        # https://stackoverflow.com/a/12574002
        table_widget.horizontalHeader().setSortIndicatorShown(False)

        table_widget.horizontalHeader().setSectionsClickable(False)
        table_widget.verticalHeader().setVisible(False)

        if is_league:
            item = table_widget.horizontalHeaderItem(1)
            item.setText(_translate("dialog", "Username"))
            item = table_widget.horizontalHeaderItem(2)
            item.setText(_translate("dialog", "XP"))
            item = table_widget.horizontalHeaderItem(3)
            item.setText(_translate("dialog", "Minutes"))
            item = table_widget.horizontalHeaderItem(4)
            item.setText(_translate("dialog", "Reviews"))
            item = table_widget.horizontalHeaderItem(5)
            item.setText(_translate("dialog", "Retention %"))
            item = table_widget.horizontalHeaderItem(6)
            item.setText(_translate("dialog", "Days studied %"))
        else:
            item = table_widget.horizontalHeaderItem(1)
            item.setText(_translate("dialog", "Username"))
            item = table_widget.horizontalHeaderItem(2)
            item.setText(_translate("dialog", "Reviews today"))
            item = table_widget.horizontalHeaderItem(3)
            item.setText(_translate("dialog", "Minutes today"))
            item = table_widget.horizontalHeaderItem(4)
            item.setText(_translate("dialog", "Streak"))
            item = table_widget.horizontalHeaderItem(5)
            item.setText(_translate("dialog", "Past 31 days"))
            item = table_widget.horizontalHeaderItem(6)
            item.setText(_translate("dialog", "Retention %"))

        if self.config.get("gamification_mode", True):
            item = table_widget.horizontalHeaderItem(7)
            is_mini_mode = self.config.get("mini_mode", False)
            if is_mini_mode:
                item.setText("🏆")
            else:
                item.setText("🏆Rank")
            item = table_widget.horizontalHeaderItem(8)
            if is_mini_mode:
                item.setText("🌎️")
            else:
                item.setText("🌎️Country")
            item.setTextAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)

        resizeMode = QHeaderView.ResizeMode.ResizeToContents
        header = table_widget.horizontalHeader()
        header.setSectionResizeMode(0, resizeMode)
        header.setSectionResizeMode(1, resizeMode)
        header.setSectionResizeMode(2, resizeMode)
        header.setSectionResizeMode(3, resizeMode)
        header.setSectionResizeMode(4, resizeMode)
        header.setSectionResizeMode(5, resizeMode)
        header.setSectionResizeMode(6, resizeMode)

        if self.config.get("gamification_mode", True):
            header.setSectionResizeMode(7, resizeMode)
            header.setSectionResizeMode(8, QHeaderView.ResizeMode.Stretch)

            rearrange_columns(self, table_widget)

        return table_widget

    def extract_user_data(self, user_data):
        username = user_data[0]
        streak = user_data[1]
        cards = user_data[2]
        time = user_data[3]
        sync_date = user_data[4]
        sync_date = datetime.datetime.strptime(sync_date, '%Y-%m-%d %H:%M:%S.%f')
        month = user_data[5]

        groups = []
        if user_data[6]:
            # Subject?
            groups.append(user_data[6].replace(" ", ""))

        country = user_data[7] #type: str
        retention = user_data[8]

        if user_data[9]:
            # groups
            for group in json.loads(user_data[9]):
                groups.append(group)

        new_groups = []
        for group in groups:
            group:str
            new_groups.append(group.replace(" ", ""))
        groups = new_groups

        if self.config["show_medals"] == True:
            medal_users = self.config["medal_users"]
            for i in medal_users:
                if username in i:
                    username = f"{username} |"
                    if i[1] > 0:
                        username = f"{username} {i[1] if i[1] != 1 else ''}🥇"
                    if i[2] > 0:
                        username = f"{username} {i[2] if i[2] != 1 else ''}🥈"
                    if i[3] > 0:
                        username = f"{username} {i[3] if i[3] != 1 else ''}🥉"

        return username, streak, cards, time, sync_date, month, groups, country, retention

    def calculate_dates(self, minus_number=1):
        new_day = datetime.time(int(self.config["newday"]), 0, 0)
        time_now = datetime.datetime.now().time()
        if time_now < new_day:
            start_day = datetime.datetime.combine(date.today() - timedelta(days=1), new_day)
            start_day_minus_thirty = start_day - timedelta(days=30)
            start_day_minus_one = start_day - timedelta(days=minus_number)
        else:
            start_day = datetime.datetime.combine(date.today(), new_day)
            start_day_minus_thirty = start_day - timedelta(days=30)
            start_day_minus_one = start_day - timedelta(days=minus_number)
        return start_day, start_day_minus_thirty, start_day_minus_one

    ## Wihitn one month ##
    def save_within_one_month(self, dict_name, username, streak, cards, time, sync_date, month, groups, country, retention):
        one_month_list = self.within_one_month_users.get(dict_name, []) #type: list
        one_month_list.append([username, streak, cards, time, sync_date, month, groups, country, retention])
        self.within_one_month_users[dict_name] = one_month_list

    def sort_within_one_month_list(self):
        for key, one_month_list in self.within_one_month_users.items():
            one_month_list:list
            one_month_list.sort(key=lambda item: item[4], reverse=True)
            # self.within_one_month_users[key] = one_month_list

            ## origin ##
                # username = item[0]
                # streak = item[1]
                # cards = item[2]
                # time = item[3]
                # sync_date = item[4]
                # month = item[5]
                # groups = item[6]
                # country = item[7]
                # retention = item[8]

            ## add item ##
                # username = item[0]
                # cards = item[1]
                # time = item[2]
                # streak = item[3]
                # month = item[4]
                # retention = item[5]
                # counter = item[6]
                # sync_date = item[7]

            if key == "friend_board":

                total_user = len(self.friends_cache)

                rank_counter = 0
                new_one_month_list = []

                for item in one_month_list:

                    rank_counter += 1
                    new_counter = total_user + rank_counter

                    username = item[0]
                    streak = item[1]
                    cards = item[2]
                    time = item[3]
                    sync_date = item[4]
                    month = item[5]
                    groups = item[6]
                    country = item[7]
                    retention = item[8]

                    # new_one_month_list.append([username, cards, time, streak, month, retention, new_counter, sync_date])
                    new_one_month_list.append([username, None, None, None, None, None, new_counter, sync_date])

                self.friends_cache.extend(new_one_month_list)

            elif key == "country_and_group":

                self.all_groups_cache

                (start_day, start_day_minus_thirty, start_day_minus_seven) = self.calculate_dates(6)

                for item in one_month_list:

                    username = item[0]
                    streak = item[1]
                    cards = item[2]
                    time = item[3]
                    sync_date = item[4]
                    month = item[5]
                    groups = item[6]
                    country = item[7] #type:str
                    retention = item[8]

                    ### Country ###
                    trim_country_name = country.replace(" ", "")

                    each_country_total_users = self.each_country_counter.get(trim_country_name, 0)
                    each_country_total_users += 1

                    country_data = self.each_country_reviews.get(trim_country_name, [0, 0])

                    if sync_date > start_day_minus_seven:
                        # 過去7日まで計算に含む
                        each_country_reviews = country_data[0] + int(month)
                    else:
                        each_country_reviews = country_data[0]

                    coutry_cache = self.all_country_cache.get(trim_country_name, []) #type: list
                    # coutry_cache.append([username, cards, time, streak, month, retention, each_country_total_users, sync_date])
                    coutry_cache.append([username, None, None, None, None, None, each_country_total_users, sync_date])

                    self.each_country_counter[trim_country_name] = each_country_total_users
                    self.all_country_cache[trim_country_name] = coutry_cache
                    self.each_country_reviews[trim_country_name] = [each_country_reviews, each_country_total_users]


                    ### Groups ###
                    for another_user_group_name in groups:
                        another_user_group_name:str
                        trim_another_user_group_name:str = another_user_group_name.replace(" ", "")
                        if trim_another_user_group_name in self.user_groups_name_list:

                            each_group_counter = self.each_group_counter.get(trim_another_user_group_name, 0)
                            each_group_counter += 1

                            groups_cache = self.all_groups_cache.get(trim_another_user_group_name, []) #type: list
                            groups_cache.append([username, None, None, None, None, None, each_group_counter, sync_date])

                            self.each_group_counter[trim_another_user_group_name] = each_group_counter
                            self.all_groups_cache[trim_another_user_group_name] = groups_cache


    ### Culculate main ###
    def calculate_leaderboard(self, table_widget:QTableWidget):

        table_widget.setRowCount(0)

        (start_day, start_day_minus_thirty, start_day_minus_one
            ) = self.calculate_dates(1) # yesterday

        # online dot
        self.start_day = start_day
        self.start_day_minus_one = start_day_minus_one

        global_counter = 0
        country_counter = 0
        friend_counter = 0

        self.global_cache = []
        self.friends_cache = []

        ## Country ##
        self.country_cache = []
        self.all_country_cache = {}
        self.each_country_counter = {}
        self.each_country_reviews = {}

        self.all_users_country_dict = {}

        ## Groups ###
        self.groups_cache = []
        self.all_groups_cache = {}
        self.each_group_counter = {}

        ## wihin one month
        self.within_one_month_users = {}

        ## user ##
        self.user_score = []
        self.user_groups_name_list = []

        # set user groups list
        self.user_groups_name_list = []
        for user_group_names in self.config["groups"]:
            user_group_names:str
            self.user_groups_name_list.append(user_group_names.replace(" ", ""))

        ## today or yesterday
        if self.config.get("start_yesterday", True):
            start_today_or_yesterday = start_day_minus_one
        else:
            start_today_or_yesterday = start_day

        ### culculate ###
        for item in self.response[0]:

            (username, streak, cards, time, sync_date, month, groups, country, retention
                ) = self.extract_user_data(item)

            if country.replace(" ", "") not in COUNTRY_LIST_V2.keys():
                country = "Country"


            # if ( self.config.get("add_pic_country_and_league", True)
            #     and self.config.get("gamification_mode", True)):
            if True:
                if sync_date > start_today_or_yesterday and username.split(" |")[0] not in self.config["hidden_users"]:

                    # save country
                    self.all_users_country_dict[username.split(" |")[0]] = country.replace(" ", "")

                    # global
                    global_counter += 1
                    self.global_cache.append([username, cards, time, streak, month, retention, global_counter, sync_date])

                    ## save user socer ##
                    if username.split(" |")[0] == self.config["username"]:
                        self.user_score = [username, cards, time, streak, month, retention, global_counter, sync_date]
                        self.user_rank_global = global_counter

                    ### Country ###
                    trim_country_name = country.replace(" ", "")

                    each_country_total_users = self.each_country_counter.get(trim_country_name, 0)
                    each_country_total_users += 1

                    country_data = self.each_country_reviews.get(trim_country_name, [0, 0])
                    each_country_reviews = country_data[0] + int(month)

                    coutry_cache = self.all_country_cache.get(trim_country_name, []) #type: list
                    coutry_cache.append([username, cards, time, streak, month, retention, each_country_total_users, sync_date])

                    self.each_country_counter[trim_country_name] = each_country_total_users
                    self.all_country_cache[trim_country_name] = coutry_cache
                    self.each_country_reviews[trim_country_name] = [each_country_reviews, each_country_total_users]

                    if username.split(" |")[0] == self.config["username"]:
                        self.user_rank_country = each_country_total_users

                    ### Groups ###
                    for another_user_group_name in groups:
                        another_user_group_name:str
                        trim_another_user_group_name:str = another_user_group_name.replace(" ", "")
                        if trim_another_user_group_name in self.user_groups_name_list:

                            each_group_counter = self.each_group_counter.get(trim_another_user_group_name, 0)
                            each_group_counter += 1

                            groups_cache = self.all_groups_cache.get(trim_another_user_group_name, []) #type: list
                            groups_cache.append([username, cards, time, streak, month, retention, each_group_counter, sync_date])

                            self.each_group_counter[trim_another_user_group_name] = each_group_counter
                            self.all_groups_cache[trim_another_user_group_name] = groups_cache

                            if username.split(" |")[0] == self.config["username"]:
                                self.user_rank_groups[trim_another_user_group_name] = each_group_counter


                    if username.split(" |")[0] in self.config["friends"]:
                        friend_counter += 1
                        self.friends_cache.append([username, cards, time, streak, month, retention, friend_counter, sync_date])
                        if username.split(" |")[0] == self.config["username"]:
                            self.user_rank_friends = friend_counter

                # Country and group within one month
                elif sync_date > start_day_minus_thirty and username.split(" |")[0] not in self.config["hidden_users"]:
                    self.save_within_one_month("country_and_group", username, streak, cards, time, sync_date, month, groups, country, retention)
                    # save country
                    self.all_users_country_dict[username.split(" |")[0]] = country.replace(" ", "")

                    # Friends (within one month)
                    if username.split(" |")[0] in self.config["friends"]:
                        self.save_within_one_month("friend_board", username, streak, cards, time, sync_date, month, groups, country, retention)
                        # save Friends
                        self.all_users_country_dict[username.split(" |")[0]] = country.replace(" ", "")

                # Friends (always display)
                elif username.split(" |")[0] in self.config["friends"]:
                    self.save_within_one_month("friend_board", username, streak, cards, time, sync_date, month, groups, country, retention)
                    # save Friends
                    self.all_users_country_dict[username.split(" |")[0]] = country.replace(" ", "")

        self.sort_within_one_month_list()


    def startSync(self):
        try:
            from ..custom_shige.custom_tooltip import shigeToolTip
            shigeToolTip("Leaderboard: now loading...", 3000,  mw)
        except:
            pass
        shigeTaskTimer.start("startSync")

        op = QueryOp(
            parent=mw,
            op=lambda col: self.sync(),
            success=self.on_success
            )

        if pointVersion() >= 231000:
            op.without_collection()

        op.run_in_background()


    def sync(self):
        self.streak, cards, time, cardsPast30Days, retention, leagueReviews, leagueTime, leagueRetention, leagueDaysPercent = Stats(self.season_start, self.season_end)

        if datetime.datetime.now() < self.season_end:
            data = {"username": self.config["username"], "streak": self.streak, "cards": cards, "time": time, "syncDate": datetime.datetime.now(),
            "month": cardsPast30Days, "country": self.config["country"].replace(" ", ""), "retention": retention,
            "leagueReviews": leagueReviews, "leagueTime": leagueTime, "leagueRetention": leagueRetention, "leagueDaysPercent": leagueDaysPercent,
            "authToken": self.config["authToken"], "version": version, "updateLeague": True, "sortby": self.config["sortby"]}
        else:
            data = {"username": self.config["username"], "streak": self.streak, "cards": cards, "time": time, "syncDate": datetime.datetime.now(),
            "month": cardsPast30Days, "country": self.config["country"].replace(" ", ""), "retention": retention,
            "authToken": self.config["authToken"], "version": version, "updateLeague": False, "sortby": self.config["sortby"]}

        self.response = postRequest("sync/", data, 200, False)
        try:
            if self.response.status_code == 200:

                try:
                    # debug only
                    debug_data_json = self.response.headers.get('X-shige-debug-data')
                except Exception as e:
                    print(f"[{ADDON_NAME}] Error: {e}")

                self.response = self.response.json()
                write_config("homescreen_data", [])

                try:
                    # api (beta)
                    from ..api_leaderboard_data import _leaderboard_data, RESPONSE_JSON, USER_NAME
                    _leaderboard_data.save_data(RESPONSE_JSON, self.response)
                    _leaderboard_data.save_data(USER_NAME, self.config.get("username"))

                except Exception as e:
                    print(e)


                #MARK:debug save json
                try:
                    from ..config_local import get_local_config, get_user_files_path
                    if get_local_config().get("debug_mode"):
                        save_path = os.path.join(get_user_files_path(), "_leaderboard_response.json")
                        with open(save_path, "w", encoding="utf-8") as f:
                            json.dump(self.response, f, ensure_ascii=False, indent=2)
                            print(f"[{ADDON_NAME}] debug: save json")

                    if debug_data_json:
                        debug_data = json.loads(debug_data_json)
                        for line in debug_data:
                            print(f"[{ADDON_NAME}] {line}")

                except Exception as e:
                    print(f"[{ADDON_NAME}] Error: {e}")


                return False
            else:
                return self.response.text
        except Exception as e:
            response = f"<h1>Something went wrong</h1>{self.response if isinstance(self.response, str) else ''}<br><br>{str(e)}"
            return response

    def on_success(self, result):
        if self.cancel_execution:
            return
        shigeTaskTimer.end("startSync")
        if result:
            if "Timeout" in result:
                custom_error()
            else:
                custom_error(result)
        else:
            ### test ###
            try:
                shigeTaskTimer.start("calculate_leaderboard")

                self.calculate_league = CalculateLeague(self, self.response)
                self.calculate_leaderboard(self.Global_Leaderboard)

                from .leaderboardV2 import LeaderBoardV2
                self.pagination_board = LeaderBoardV2(self, mw)
                self.pagination_board.show()

                ### show tooltip ###
                # if self.config.get("add_pic_country_and_league", True):
                if True:
                    if hasattr(self, 'now_your_stats_tooltip'):
                        if isinstance(self.now_your_stats_tooltip, str):
                            tooltip(
                                    msg=self.now_your_stats_tooltip,
                                    period = 7000,
                                    parent=self.pagination_board,
                                    y_offset = 184
                                    )


                achievement(self.pagination_board, self.streak)

            except RuntimeError:
                print("RuntimeError")
                return


    def add_row(self, table_widget:"QTableWidget", username:str, cards, time, streak, month, retention, counter, sync_date):
        rowPosition = table_widget.rowCount()

        if self.config.get("gamification_mode", True):
            table_widget.setColumnCount(9)
        else:
            table_widget.setColumnCount(7)

        table_widget.insertRow(rowPosition)

        text_color_grey = None
        if not table_widget == self.League_Leaderboard:
            if sync_date is None or sync_date < self.start_day_minus_one:
                text_color_grey = QColor("#808080")

        item = QTableWidgetItem()
        if counter is not None:
            item.setData(Qt.ItemDataRole.DisplayRole, int(counter))
            self.set_font_and_size_item(item)
        table_widget.setItem(rowPosition, 0, item)
        item.setTextAlignment(Qt.AlignmentFlag.AlignRight|Qt.AlignmentFlag.AlignVCenter)
        if text_color_grey:
            item.setForeground(text_color_grey)

        item = QTableWidgetItem()
        is_coins = None
        if username is not None:
            # if self.config.get("mini_mode", False) and " |" in username:
            if " |" in username:
                display_username = username.replace(" |", " |\n")
                is_coins = True
            else:
                display_username = username
            item.setData(Qt.ItemDataRole.DisplayRole, str(display_username))
            self.set_font_and_size_item(item)
        table_widget.setItem(rowPosition, 1, item)
        if text_color_grey:
            item.setForeground(text_color_grey)

        item = QTableWidgetItem()
        if cards is not None:
            item.setData(Qt.ItemDataRole.DisplayRole, int(cards))
            self.set_font_and_size_item(item)
        table_widget.setItem(rowPosition, 2, item)
        # item.setTextAlignment(Qt.AlignmentFlag.AlignRight|Qt.AlignmentFlag.AlignVCenter)
        item.setTextAlignment(Qt.AlignmentFlag.AlignLeft|Qt.AlignmentFlag.AlignVCenter)
        if text_color_grey:
            item.setForeground(text_color_grey)

        item = QTableWidgetItem()
        if time is not None:
            item.setData(Qt.ItemDataRole.DisplayRole, float(time))
            self.set_font_and_size_item(item)
        table_widget.setItem(rowPosition, 3, item)
        item.setTextAlignment(Qt.AlignmentFlag.AlignRight|Qt.AlignmentFlag.AlignVCenter)
        if text_color_grey:
            item.setForeground(text_color_grey)

        item = QTableWidgetItem()
        if streak is not None:
            item.setData(Qt.ItemDataRole.DisplayRole, int(streak))
            self.set_font_and_size_item(item)
        table_widget.setItem(rowPosition, 4, item)
        item.setTextAlignment(Qt.AlignmentFlag.AlignRight|Qt.AlignmentFlag.AlignVCenter)

        item = QTableWidgetItem()
        if month is not None:
            item.setData(Qt.ItemDataRole.DisplayRole, int(month))
            self.set_font_and_size_item(item)
        table_widget.setItem(rowPosition, 5, item)
        item.setTextAlignment(Qt.AlignmentFlag.AlignRight|Qt.AlignmentFlag.AlignVCenter)
        if text_color_grey:
            item.setForeground(text_color_grey)

        item = QTableWidgetItem()
        if retention is not None:
            item.setData(Qt.ItemDataRole.DisplayRole, float(retention))
            self.set_font_and_size_item(item)
        table_widget.setItem(rowPosition, 6, item)
        item.setTextAlignment(Qt.AlignmentFlag.AlignRight|Qt.AlignmentFlag.AlignVCenter)
        if text_color_grey:
            item.setForeground(text_color_grey)

        from .add_pic_global import add_pic_global_friend_group
        user_items = [username, cards, time, streak, month, retention, counter, sync_date]
        add_pic_global_friend_group(self, table_widget, user_items, rowPosition)

        self.online_dot(table_widget, sync_date)

        if is_coins:
            table_widget.resizeRowToContents(rowPosition)



    def online_dot(self, leaderbord:QTableWidget, sync_date):
        if leaderbord == self.League_Leaderboard:
            return
        if not self.config.get("is_online_dot", True):
            return
        if self.start_day == None:
            return
        if not isinstance(sync_date, datetime.datetime):
            return

        icon_path = None

        if not sync_date > self.start_day:
            if sync_date > self.start_day_minus_one:
                icon_path = QIcon(ONLINE_DOT[1])
        elif sync_date > self.start_day:
            icon_path = QIcon(ONLINE_DOT[0])

        if icon_path:
            row_position = leaderbord.rowCount() - 1
            item = leaderbord.item(row_position, 0)
            if item:
                item.setIcon(icon_path)


    def set_last_row_items_to_gray(self, leaderbord:QTableWidget, sync_date, start_day):
        # not used yet
        if not self.config.get("is_online_dot", True):
            return

        icon_path = None
        is_today = False
        if not sync_date > start_day:
            icon_path = QIcon(ONLINE_DOT[1])
        elif sync_date > start_day:
            icon_path = QIcon(ONLINE_DOT[0])
            is_today = True

        if icon_path:
            row_position = leaderbord.rowCount() - 1
            item = leaderbord.item(row_position, 0)
            if item:
                item.setIcon(icon_path)


    def updateNumbers(self, table_widget:QTableWidget):
        rows = table_widget.rowCount()
        for i in range(0, rows):

            existing_item = table_widget.item(i, 0)
            icon = None
            if existing_item:
                icon = existing_item.icon()

            item = QTableWidgetItem()
            item.setData(Qt.ItemDataRole.DisplayRole, int(i + 1))

            if icon and not icon.isNull():
                item.setIcon(icon)

            table_widget.setItem(i, 0, item)
            item.setTextAlignment(Qt.AlignmentFlag.AlignRight|Qt.AlignmentFlag.AlignVCenter)

    def highlight(self, table_widget:QTableWidget, current_page=0):

        is_user_row_number = False
        for i in range(table_widget.rowCount()):
            user_name = table_widget.item(i, 1).text().split(" |")[0]
            if i % 2 == 0:
                for j in range(table_widget.columnCount()):
                    table_widget.item(i, j).setBackground(QColor(self.colors["ROW_LIGHT"]))
            else:
                for j in range(table_widget.columnCount()):
                    table_widget.item(i, j).setBackground(QColor(self.colors["ROW_DARK"]))
            if user_name in self.config["friends"] and table_widget != self.Friends_Leaderboard:
                for j in range(table_widget.columnCount()):
                    table_widget.item(i, j).setBackground(QColor(self.colors["FRIEND_COLOR"]))
            if user_name == self.config["username"]:
                for j in range(table_widget.columnCount()):
                    table_widget.item(i, j).setBackground(QColor(self.colors["USER_COLOR"]))

                table_widget.user_row_number = i
                is_user_row_number = True

        if not is_user_row_number:
            table_widget.user_row_number = 0

        # add highlight league
        if table_widget == self.League_Leaderboard:
            highlight_league(self, table_widget, current_page)

        # Add highlight only for page 1
        if table_widget.rowCount() >= 3 and current_page == 1 and table_widget.item(2, 1).text().split(" |")[0].strip():
            for j in range(table_widget.columnCount()):
                if table_widget.item(0, 1).text().split(" |")[0].strip():
                    table_widget.item(0, j).setBackground(QColor(self.colors["GOLD_COLOR"]))
                if table_widget.item(1, 1).text().split(" |")[0].strip():
                    table_widget.item(1, j).setBackground(QColor(self.colors["SILVER_COLOR"]))
                if table_widget.item(2, 1).text().split(" |")[0].strip():
                    table_widget.item(2, j).setBackground(QColor(self.colors["BRONZE_COLOR"]))


    def user_info(self, tab:QTableWidget):
        for idx in tab.selectionModel().selectedIndexes():
            row = idx.row()
        user_clicked = tab.item(row, 1).text()
        if tab == self.Custom_Leaderboard:
            enabled = True
        else:
            enabled = False
        mw.shige_user_info = start_user_info(user_clicked, enabled, tab)
        mw.shige_user_info.show()
        mw.shige_user_info.raise_()
        mw.shige_user_info.activateWindow()

    def update_row_items(self, table_widget:QTableWidget, current_page=1):
        # for wait cursor.
        try:
            mw.app.setOverrideCursor(QCursor(Qt.CursorShape.WaitCursor))
            self.try_update_row_items(table_widget, current_page)
        except Exception as e:
            raise e
        finally:
            mw.app.restoreOverrideCursor()

    ### update rows ###
    def try_update_row_items(self, table_widget:QTableWidget, current_page=1):

        self.config = mw.addonManager.getConfig(__name__)

        # Prevent flicker 01
        table_widget.setUpdatesEnabled(False)

        if table_widget == self.Global_Leaderboard:
            board_cache = self.global_cache
        elif table_widget == self.Friends_Leaderboard:
            board_cache = self.friends_cache
        elif table_widget == self.Country_Leaderboard:
            board_cache = self.country_cache
        elif table_widget == self.Custom_Leaderboard:
            board_cache = self.groups_cache
        elif table_widget == self.League_Leaderboard:
            board_cache = self.league_cache

        self.total_rows = max(0, len(board_cache)) if board_cache else 0

        start_idx = (current_page - 1) * self.page_size
        end_idx = start_idx + self.page_size

        if not table_widget.is_auto_scroll:
            table_widget.setRowCount(0)
            table_widget.verticalScrollBar().setValue(0)
        else:
            previous_scroll_value = table_widget.verticalScrollBar().maximum()

        if table_widget.is_auto_scroll_top:
            saved_items = []
            for row in range( table_widget.rowCount()):
                row_items = []
                for col in range(table_widget.columnCount()):
                    item = table_widget.item(row, col)
                    if item:
                        cloned_item = QTableWidgetItem(item)
                        row_items.append(cloned_item)
                    else:
                        row_items.append(None)
                saved_items.append(row_items)
            table_widget.setRowCount(0)

        pre_buffer = 0
        post_buffer = 0

        buffer_start_idx = max(0, start_idx - pre_buffer)
        buffer_end_idx = min(self.total_rows, end_idx + post_buffer)

        added_rows = 0

        # if self.config.get("add_pic_country_and_league", True):
        if True:
            self.user_icons_downloader.execution_count = 0 #

        if board_cache:
            for row in board_cache[buffer_start_idx:buffer_end_idx]:
                self.add_row(table_widget, *row)
                added_rows += 1

        for _ in range(self.page_size - added_rows):
            self.add_row(table_widget, None, None, None, None, None, None, None, None)

        # table_widget.resizeRowsToContents()

        table_widget.viewport().setCursor(QCursor(Qt.CursorShape.ArrowCursor))

        # if self.config.get("add_pic_country_and_league", True):
        if True:
            self.user_icons_downloader.dl_icons_in_background()

        table_widget.setSortingEnabled(False)

        try:
            table_widget.doubleClicked.disconnect()
        except TypeError:
            pass

        table_widget.doubleClicked.connect(lambda: self.user_info(table_widget))

        set_mini_mode(self, table_widget)

        # if (self.config.get("add_pic_country_and_league", True) and self.config.get("gamification_mode", True)):
        if True:
            shigeTaskTimer.start("custom_column_size")
            custom_column_size(self, table_widget)
            shigeTaskTimer.end("custom_column_size")

        if table_widget.is_auto_scroll_top:
            current_rows_count = table_widget.rowCount()
            saved_rows_count = len(saved_items)
            for i in range(saved_rows_count):
                row_to_insert = current_rows_count + i
                table_widget.insertRow(row_to_insert)
                for col in range(table_widget.columnCount()):
                    item = saved_items[i][col]
                    if item:
                        table_widget.setItem(row_to_insert, col, item)

        self.highlight(table_widget, current_page)

        SafeQTimer.singleShot(0, lambda: table_widget.setUpdatesEnabled(True))

        ### push button & user position scroll ###
        table_widget.clearSelection()
        if not table_widget.is_auto_scroll:
            if ((self.config["scroll"] == True or table_widget.manually_scroll == True)
                and table_widget.user_row_number
                and not table_widget.manually_top
                ):
                table_widget.manually_scroll = False
                model_index = table_widget.model().index(table_widget.user_row_number, 0)
                SafeQTimer.singleShot(150, lambda: (
                    table_widget.scrollTo(
                    model_index, QAbstractItemView.ScrollHint.PositionAtCenter)))
            else:
                table_widget.manually_top = False
                SafeQTimer.singleShot(150, lambda: table_widget.verticalScrollBar().setValue(0))

        ### auto scroll ###
        if table_widget.is_auto_scroll:
            if table_widget.is_auto_scroll_top: # scroll to top
                target_row = min(self.page_size, table_widget.rowCount() - 1)
                target_item = table_widget.item(target_row, 0)
                if target_item:
                    SafeQTimer.singleShot(
                        100,
                        lambda: table_widget.scrollToItem(target_item, hint=QAbstractItemView.ScrollHint.PositionAtTop))
            else: # scroll to bottom
                SafeQTimer.singleShot(100, lambda: table_widget.verticalScrollBar().setValue(previous_scroll_value))
            table_widget.is_auto_scroll = False


