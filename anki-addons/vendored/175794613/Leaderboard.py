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

import datetime
from datetime import date, timedelta
import json
import os
from os.path import dirname, join, realpath

from aqt import QBrush, QCloseEvent, QColor, QHBoxLayout, QHeaderView, QLabel, QMoveEvent, QPainter, QPushButton, QResizeEvent, QSizePolicy, QTableWidget, QTableWidgetItem, QTimer, mw
from aqt.theme import theme_manager
from aqt.qt import QDialog, Qt, QIcon, QPixmap, qtmajor, QAbstractItemView
from aqt.operations import QueryOp
from aqt.utils import showWarning, tooltip, openLink
from anki.utils import pointVersion

from .custom_shige.path_manager import ONLINE_DOT, PATREON_URL

from .custom_shige.random_error import custom_error
from .icon_downloader import IconDownloader

if qtmajor > 5:
    from .forms.pyqt6UI import Leaderboard
    from PyQt6 import QtCore, QtGui, QtWidgets
else:
    from .forms.pyqt5UI import Leaderboard
    from PyQt5 import QtCore, QtGui, QtWidgets
from .Stats import Stats
from .Achievement import start_achievement
from .config_manager import write_config

from .league import load_league

from .userInfo import start_user_info
from .version import version
from .api_connect import getRequest, postRequest
# from .custom_shige.web_Leaderboard import add_web_leaderboard_tab

from .check_user_rank import SaveUserRankings
from .custom_shige.country_dict import COUNTRY_LIST
from .custom_shige.count_time import shigeTaskTimer
from .custom_shige.rate_limit_timer import rate_limit

# START_YESTERDAY = True
IS_ONLINE_DOT = True

YESTERDAY_USERS_GRAY = False #📍test

START_ONE_MONTH = False #📍test



class start_main(QDialog):
    def __init__(self, season_start, season_end, current_season, parent=None):
        self.parent = parent
        self.season_start = season_start
        self.season_end = season_end
        self.current_season = current_season
        self.groups_lb = []
        self.within_one_month_groups_lb = []
        self.is_save_zoom = False
        self.user_league_name = "Delta"

        self.config = mw.addonManager.getConfig(__name__)

        self.save_all_users_ranking = SaveUserRankings()

        QDialog.__init__(self, parent, Qt.WindowType.Window)
        self.dialog = Leaderboard.Ui_dialog()
        self.dialog.setupUi(self)

        # try:
        #     nightmode = theme_manager.night_mode
        # except:
        #     #for older versions
        #     try:
        #         nightmode = mw.pm.night_mode()
        #     except:
        #         nightmode = False
        #     nightmode = False

        # with open(join(dirname(realpath(__file__)), "colors.json"), "r") as colors_file:
        #     data = colors_file.read()
        # colors_themes = json.loads(data)
        # self.colors = colors_themes["dark"] if nightmode else colors_themes["light"]

        from .colors_config import get_color_config
        self.colors = get_color_config()


        # added
        if self.config.get("add_pic_country_and_league", True):
            self.user_icons_downloader = IconDownloader(self)

        self.setupUI()

        # test
        # add_web_leaderboard_tab(self, self.dialog.Parent)


    def closeEvent(self, event: QCloseEvent):
        # ﾘｰﾀﾞｰﾎﾞｰﾄﾞを閉じるときの処理を追加
        if hasattr(self, "user_icons_downloader"):
            self.user_icons_downloader.stop_download_flag = True

        super().closeEvent(event)


    def resizeEvent(self, event:"QResizeEvent"):
        if self.is_save_zoom:
            if not rate_limit.limit("resizeEvent", 0.1):
                size = event.size()
                write_config("board_size", [size.width(), size.height()])
        super().resizeEvent(event)

    def moveEvent(self, event: QMoveEvent):
            if self.is_save_zoom:
                if not rate_limit.limit("resizeEvent", 0.1):
                    pos = self.pos()
                    write_config("board_position", [pos.x(), pos.y()])
            super().moveEvent(event)



    def setupUI(self):
        _translate = QtCore.QCoreApplication.translate

        icon = QIcon()
        icon.addPixmap(QPixmap(join(dirname(realpath(__file__)), "designer/icons/krone.png")), QIcon.Mode.Normal, QIcon.State.Off)
        self.setWindowIcon(icon)

        # header1 = self.dialog.Global_Leaderboard.horizontalHeader()
        # header1.sectionClicked.connect(lambda: self.updateTable(self.dialog.Global_Leaderboard))
        # header2 = self.dialog.Friends_Leaderboard.horizontalHeader()
        # header2.sectionClicked.connect(lambda: self.updateTable(self.dialog.Friends_Leaderboard))
        # header3 = self.dialog.Country_Leaderboard.horizontalHeader()
        # header3.sectionClicked.connect(lambda: self.updateTable(self.dialog.Country_Leaderboard))
        # header4 = self.dialog.Custom_Leaderboard.horizontalHeader()
        # header4.sectionClicked.connect(lambda: self.updateTable(self.dialog.Custom_Leaderboard))

        header1 = self.dialog.Global_Leaderboard.horizontalHeader()
        header1.sectionClicked.connect(lambda logicalIndex: self.updateTable(self.dialog.Global_Leaderboard, logicalIndex))
        header2 = self.dialog.Friends_Leaderboard.horizontalHeader()
        header2.sectionClicked.connect(lambda logicalIndex: self.updateTable(self.dialog.Friends_Leaderboard, logicalIndex))
        header3 = self.dialog.Country_Leaderboard.horizontalHeader()
        header3.sectionClicked.connect(lambda logicalIndex: self.updateTable(self.dialog.Country_Leaderboard, logicalIndex))
        header4 = self.dialog.Custom_Leaderboard.horizontalHeader()
        header4.sectionClicked.connect(lambda logicalIndex: self.updateTable(self.dialog.Custom_Leaderboard, logicalIndex))


        tab_widget = self.dialog.Parent
        country_tab = tab_widget.indexOf(self.dialog.tab_3)
        subject_tab = tab_widget.indexOf(self.dialog.tab_4)
        tab_widget.setTabText(country_tab, self.config["country"])
        for i in range(0, len(self.config["groups"])):
            self.dialog.groups.addItem("")
            self.dialog.groups.setItemText(i, _translate("Dialog", self.config["groups"][i]))
        self.dialog.groups.setCurrentText(self.config["current_group"])
        # self.dialog.groups.currentTextChanged.connect(lambda: self.updateTable(self.dialog.Custom_Leaderboard))
        self.dialog.groups.currentTextChanged.connect(lambda: self.updateTable(self.dialog.Custom_Leaderboard, None, True))
        self.dialog.Parent.setCurrentIndex(self.config["tab"])

        self.dialog.Global_Leaderboard.doubleClicked.connect(lambda: self.user_info(self.dialog.Global_Leaderboard))
        self.dialog.Global_Leaderboard.setToolTip("Double click on user for more info.")
        self.dialog.Friends_Leaderboard.doubleClicked.connect(lambda: self.user_info(self.dialog.Friends_Leaderboard))
        self.dialog.Friends_Leaderboard.setToolTip("Double click on user for more info.")
        self.dialog.Country_Leaderboard.doubleClicked.connect(lambda: self.user_info(self.dialog.Country_Leaderboard))
        self.dialog.Country_Leaderboard.setToolTip("Double click on user for more info.")
        self.dialog.Custom_Leaderboard.doubleClicked.connect(lambda: self.user_info(self.dialog.Custom_Leaderboard))
        self.dialog.Custom_Leaderboard.setToolTip("Double click on user for more info.")
        self.dialog.League.doubleClicked.connect(lambda: self.user_info(self.dialog.League))
        self.dialog.League.setToolTip("Double click on user for more info.")
        self.dialog.league_label.setToolTip("Leagues (from lowest to highest): Delta, Gamma, Beta, Alpha")

        self.startSync()

        # # Show active users count

        # self.run_active_users()

        # active_users = self.get_active_users()
        # active_users_label = QLabel(active_users)
        # active_users_label.setToolTip("Number of users synced within one month.")
        # self.dialog.verticalLayout_2.insertWidget(0, active_users_label)

    def header(self):
        lb_list = [self.dialog.Global_Leaderboard, self.dialog.Friends_Leaderboard,
        self.dialog.Country_Leaderboard, self.dialog.Custom_Leaderboard, self.dialog.League]
        for l in lb_list:
            header = l.horizontalHeader()
            header.setSectionResizeMode(0, QtWidgets.QHeaderView.ResizeMode.ResizeToContents)
            header.setSectionResizeMode(1, QtWidgets.QHeaderView.ResizeMode.Stretch)
            header.setSectionResizeMode(2, QtWidgets.QHeaderView.ResizeMode.Stretch)
            header.setSectionResizeMode(3, QtWidgets.QHeaderView.ResizeMode.Stretch)
            header.setSectionResizeMode(4, QtWidgets.QHeaderView.ResizeMode.Stretch)
            header.setSectionResizeMode(5, QtWidgets.QHeaderView.ResizeMode.Stretch)

            for i in range(0, 6):
                headerItem = l.horizontalHeaderItem(i)
                headerItem.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignCenter|QtCore.Qt.AlignmentFlag.AlignVCenter)

    def add_row(self, tab:"QTableWidget", username, cards, time, streak, month, retention):
        rowPosition = tab.rowCount()
        tab.setColumnCount(7)
        tab.insertRow(rowPosition)

        item = QtWidgets.QTableWidgetItem()
        item.setData(QtCore.Qt.ItemDataRole.DisplayRole, int(rowPosition + 1))
        tab.setItem(rowPosition, 0, item)
        item.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignRight|QtCore.Qt.AlignmentFlag.AlignVCenter)

        tab.setItem(rowPosition, 1, QtWidgets.QTableWidgetItem(str(username)))

        item = QtWidgets.QTableWidgetItem()
        item.setData(QtCore.Qt.ItemDataRole.DisplayRole, int(cards))
        tab.setItem(rowPosition, 2, item)
        item.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignRight|QtCore.Qt.AlignmentFlag.AlignVCenter)

        item = QtWidgets.QTableWidgetItem()
        item.setData(QtCore.Qt.ItemDataRole.DisplayRole, float(time))
        tab.setItem(rowPosition, 3, item)
        item.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignRight|QtCore.Qt.AlignmentFlag.AlignVCenter)

        item = QtWidgets.QTableWidgetItem()
        item.setData(QtCore.Qt.ItemDataRole.DisplayRole, int(streak))
        tab.setItem(rowPosition, 4, item)
        item.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignRight|QtCore.Qt.AlignmentFlag.AlignVCenter)

        item = QtWidgets.QTableWidgetItem()
        item.setData(QtCore.Qt.ItemDataRole.DisplayRole, int(month))
        tab.setItem(rowPosition, 5, item)
        item.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignRight|QtCore.Qt.AlignmentFlag.AlignVCenter)

        item = QtWidgets.QTableWidgetItem()
        item.setData(QtCore.Qt.ItemDataRole.DisplayRole, float(retention))
        tab.setItem(rowPosition, 6, item)
        item.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignRight|QtCore.Qt.AlignmentFlag.AlignVCenter)

    def switchGroup(self, tab:"QTableWidget"):
         
        tab.setSortingEnabled(False)
        write_config("current_group", self.dialog.groups.currentText())
        tab.setRowCount(0)
        for i in self.groups_lb:
            if self.dialog.groups.currentText().replace(" ", "") in i[6]:
                self.add_row(tab, i[0], i[1], i[2], i[3], i[4], i[5])
                self.set_last_row_items_to_gray(tab, i[7], i[8])

        # added
        for i in self.within_one_month_groups_lb:
            if self.dialog.groups.currentText().replace(" ", "") in i[6]:
                self.add_yesterday_row(tab, i[0])

        tab.setSortingEnabled(True)

    # def switchGroup(self):
    #     self.dialog.Custom_Leaderboard.setSortingEnabled(False)
    #     write_config("current_group", self.dialog.groups.currentText())
    #     self.dialog.Custom_Leaderboard.setRowCount(0)
    #     for i in self.groups_lb:
    #         if self.dialog.groups.currentText().replace(" ", "") in i[6]:
    #             self.add_row(self.dialog.Custom_Leaderboard, i[0], i[1], i[2], i[3], i[4], i[5])
    #             self.set_last_row_items_to_gray(self.dialog.Custom_Leaderboard, i[7], i[8])

    #     # added
    #     for i in self.within_one_month_groups_lb:
    #         if self.dialog.groups.currentText().replace(" ", "") in i[6]:
    #             self.add_yesterday_row(self.dialog.Custom_Leaderboard, i[0])

    #     self.dialog.Custom_Leaderboard.setSortingEnabled(True)




    # def achievement(self, streak):
    #     achievement_streak = [7, 31,
    #                             100, 365,
    #                             500, 1000,
    #                             1500, 2000,
    #                             3000, 4000]
    #     if self.config["achievement"] == True and streak in achievement_streak:
    #         s = start_achievement(streak)
    #         if s.exec():
    #             pass
    #         write_config("achievement", False)

    def achievement(self, streak):
        def is_repeating_number(n):
            s = str(n)
            if len(s) >= 3:
                return all(c == s[0] for c in s)
            return False

        if (self.config["achievement"] == True
            and streak != 0
            and (
            streak % 100 == 0
            or streak % 365 == 0
            or streak in [7, 31, 60]
            or is_repeating_number(streak)
            )
            ):
            s = start_achievement(streak, self)
            s.show()
            # if s.exec():
            #     pass
            write_config("achievement", False)


    def startSync(self):
        try:
            from .custom_shige.custom_tooltip import shigeToolTip
            shigeToolTip("Leaderboard: now loading...", 3000,  mw)
        except:
            pass
        shigeTaskTimer.start("startSync")
        # tooltip("Now loading...")
        op = QueryOp(parent=mw, op=lambda col: self.sync(), success=self.on_success)
        # op.with_progress().run_in_background()
        if pointVersion() >= 231000:
            op.without_collection()
        op.run_in_background()
        # op.with_progress().run_in_background()


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
                self.response = self.response.json()
                # test
                # self.buildLeaderboard()
                # load_league(self)

                try:
                    from .api_leaderboard_data import _leaderboard_data, RESPONSE_JSON, USER_NAME
                    _leaderboard_data.save_data(RESPONSE_JSON, self.response)
                    _leaderboard_data.save_data(USER_NAME, self.config.get("username"))
                except Exception as e:
                    print(e)

                return False
            else:
                return self.response.text
        except Exception as e:
            response = f"<h1>Something went wrong</h1>{self.response if isinstance(self.response, str) else ''}<br><br>{str(e)}"
            return response

    def on_success(self, result):
        shigeTaskTimer.end("startSync")
        if result:
            if "Timeout" in result:
                custom_error()
            else:
                custom_error(result)
                # showWarning(result, title="Leaderboard Error")
        else:
            ### test ###
            try:
                self.buildLeaderboard()
            except RuntimeError:
                print("RuntimeError")
                return
            load_league(self)
            ############
            self.run_active_users()

            self.header()
            # self.achievement(self.streak)
            # self.show()
            # self.activateWindow()

            # if hasattr(self, 'scroll_items'): # ｽｸﾛｰﾙの処理をﾊﾞｯｸｸﾞﾗﾝﾄﾞから移動
            #     for tab, userposition in self.scroll_items:
            #         tab.scrollToItem(userposition, QAbstractItemView.ScrollHint.PositionAtCenter)
            #     self.scroll_items = []

            ### HIDDEN ###
            for i in range(self.dialog.League.rowCount()):
                item = self.dialog.League.item(i, 1).text().split(" |")[0]
                if item in self.config['hidden_users']:
                    self.dialog.League.hideRow(i) # does not work well
                    self.dialog.League.setRowHeight(i, 0) # work

            ### add pic test ###
            if self.config.get("add_pic_country_and_league", True):
                shigeTaskTimer.start("add_pic")

                if self.config.get("allways_on_top", False):
                    # add_pic_globalより手前でないとﾚｲｱｳﾄが崩れる
                    self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint)

                # from .add_pic_country_league import  set_pic_league_tab
                from .add_pic_country_league import set_pic_league_tab

                from .add_pic_global import add_pic_global_friend_group
                leader_boards = [
                    [self.dialog.Friends_Leaderboard,"diamond", "Friends"],
                    [self.dialog.Country_Leaderboard,"diamond", "Country"],
                    [self.dialog.Custom_Leaderboard,"diamond", "Group"],
                    [self.dialog.Global_Leaderboard, "hexagon", "Global"],
                ]

                for tag_widget, icon_type, board_type in leader_boards:
                    shigeTaskTimer.start("add_pic_01")
                    add_pic_global_friend_group(self, tag_widget, icon_type, board_type)
                    shigeTaskTimer.end("add_pic_01")

                shigeTaskTimer.start("add_pic_02")
                from .toggle_league import set_toggle_league
                set_pic_league_tab(self)
                set_toggle_league(self)
                shigeTaskTimer.end("add_pic_02")

                self.user_icons_downloader.dl_icons_in_background()

                # new func Friend
                self.add_friend_search_button()

                # new func country
                shigeTaskTimer.start("add_pic_03")
                from .Leaderboard_country import CountryLeaderbord
                self.cosutom_country_leaderbord = CountryLeaderbord(self)
                self.cosutom_country_leaderbord.add_set_country_button()
                shigeTaskTimer.end("add_pic_03")

                shigeTaskTimer.end("add_pic")

                shigeTaskTimer.start("change_size")

                from .change_leaderboard_size import change_board_size
                leader_boards.append([self.dialog.League, "", ""])
                for tab_widget, icon_type, board_type in leader_boards:
                    change_board_size(self, tab_widget)

                ### resize ###
                zoom_enable = self.config.get("zoom_enable", True)
                board_size = self.config.get("board_size", [])
                if zoom_enable:
                    if (board_size and len(board_size) >= 2
                        and isinstance(board_size[0], int) and isinstance(board_size[1], int)
                        and board_size[0] > 0 and board_size[1] > 0):
                        self.resize(board_size[0], board_size[1])
                    else:
                        current_size = self.size()
                        new_width = int(current_size.width() * 1.2)
                        new_height = current_size.height()
                        self.resize(new_width, new_height)

                if self.config.get("gamification_mode", True):
                    shigeTaskTimer.start("custom_column_size")
                    from .custom_column import custom_column_size
                    # leader_boards.remove([self.dialog.League, "", ""])
                    for tag_widget, icon_type, board_type in leader_boards:
                        custom_column_size(self, tag_widget)
                    shigeTaskTimer.end("custom_column_size")

                    self.setMinimumSize(200, 200)

                    ### position ###
                    board_position = self.config.get("board_position", [])
                    if (board_position and len(board_position) == 2
                        and isinstance(board_position[0], int) and isinstance(board_position[1], int)
                        and board_position[0] > 0 and board_position[1] > 0):
                        self.move(board_position[0], board_position[1])

                shigeTaskTimer.end("change_size")

            ### show Window ###
            self.achievement(self.streak)
            self.show()
            self.activateWindow()
            self.is_save_zoom = True

            ### show tooltip ###
            if self.config.get("add_pic_country_and_league", True):
                if hasattr(self, 'now_your_stats_tooltip'):
                    if isinstance(self.now_your_stats_tooltip, str):
                        tooltip(
                                msg=self.now_your_stats_tooltip,
                                period = 7000,
                                parent=self,
                                y_offset = 184
                                )

            if hasattr(self, 'scroll_items'): # ｽｸﾛｰﾙの処理をﾊﾞｯｸｸﾞﾗﾝﾄﾞから移動
                #📍使ってないのでは?
                for tab, userposition in self.scroll_items:
                    tab: QTableWidget
                    tab.scrollToItem(userposition, QAbstractItemView.ScrollHint.PositionAtCenter)
                self.scroll_items = []

            # for debug only ------
            from .hide_users_name import hide_all_users_name
            hide_all_users_name(self)
            # ----------------------


    def buildLeaderboard(self):

        ### CLEAR TABLE ###

        self.dialog.Global_Leaderboard.setRowCount(0)
        self.dialog.Friends_Leaderboard.setRowCount(0)
        self.dialog.Country_Leaderboard.setRowCount(0)
        self.dialog.Custom_Leaderboard.setRowCount(0)
        self.dialog.League.setRowCount(0)

        new_day = datetime.time(int(self.config["newday"]),0,0)
        time_now = datetime.datetime.now().time()
        if time_now < new_day:
            start_day = datetime.datetime.combine(date.today() - timedelta(days=1), new_day)
            start_day_minus_thirty = start_day - timedelta(days=30)
            start_day_minus_one = start_day - timedelta(days=1)
        else:
            start_day = datetime.datetime.combine(date.today(), new_day)
            start_day_minus_thirty = start_day - timedelta(days=30)
            start_day_minus_one = start_day - timedelta(days=1)

        self.start_day = start_day

        # if START_YESTERDAY:
        #     start_day = start_day_minus_one

        if START_ONE_MONTH: # for debug
            start_day_minus_one = start_day_minus_thirty

        medal_users = self.config["medal_users"]
        self.groups_lb = []
        self.within_one_month_groups_lb = []
        c_groups = [x.replace(" ", "") for x in self.config["groups"]]

        within_one_month_users = []

        for i in self.response[0]:
            user_data = i
            username = i[0]
            streak = i[1]
            cards = i[2]
            time = i[3]
            sync_date = i[4]
            sync_date = datetime.datetime.strptime(sync_date, '%Y-%m-%d %H:%M:%S.%f')
            month = i[5]
            groups = []
            if i[6]:
                groups.append(i[6].replace(" ", ""))
            country = i[7]
            retention = i[8]
            if i[9]:
                for group in json.loads(i[9]):
                    groups.append(group)
            groups = [x.replace(" ", "") for x in groups]

            if self.config["show_medals"] == True:
                for i in medal_users:
                    if username in i:
                        username = f"{username} |"
                        if i[1] > 0:
                            username = f"{username} {i[1] if i[1] != 1 else ''}🥇"
                        if i[2] > 0:
                            username = f"{username} {i[2] if i[2] != 1 else ''}🥈"
                        if i[3] > 0:
                            username = f"{username} {i[3] if i[3] != 1 else ''}🥉"

            # 昨日を計算に含める
            # if START_YESTERDAY: # 開発中
            if ( self.config.get("add_pic_country_and_league", True)
                and self.config.get("gamification_mode", True)
                and self.config.get("start_yesterday", True)):
                if sync_date > start_day_minus_one and username.split(" |")[0] not in self.config["hidden_users"]:
                    self.add_row(self.dialog.Global_Leaderboard, username, cards, time, streak, month, retention)
                    self.set_last_row_items_to_gray(self.dialog.Global_Leaderboard, sync_date, start_day)

                    if country == self.config["country"].replace(" ", "") and country != "Country":
                        self.add_row(self.dialog.Country_Leaderboard, username, cards, time, streak, month, retention)
                        self.set_last_row_items_to_gray(self.dialog.Country_Leaderboard, sync_date, start_day)

                    c_groups = [x.replace(" ", "") for x in self.config["groups"]]
                    if any(i in c_groups for i in groups):
                        self.groups_lb.append([username, cards, time, streak, month, retention, groups, sync_date, start_day])
                        # if self.config["current_group"].replace(" ", "") in groups:
                        if self.config["current_group"] is not None and self.config["current_group"].replace(" ", "") in groups:
                            self.add_row(self.dialog.Custom_Leaderboard, username, cards, time, streak, month, retention)
                            self.set_last_row_items_to_gray(self.dialog.Custom_Leaderboard, sync_date, start_day)

                    if username.split(" |")[0] in self.config["friends"]:
                        self.add_row(self.dialog.Friends_Leaderboard, username, cards, time, streak, month, retention)
                        self.set_last_row_items_to_gray(self.dialog.Friends_Leaderboard, sync_date, start_day)

                # 今月のﾘｰﾀﾞｰﾎﾞｰﾄﾞ
                elif sync_date > start_day_minus_thirty and username.split(" |")[0] not in self.config["hidden_users"]:
                    within_one_month_users.append(user_data)

                # ﾌﾚﾝﾄﾞは常に表示する
                elif username.split(" |")[0] in self.config["friends"]:
                    within_one_month_users.append(user_data)

            else: # 今日のみ表示する(ﾃﾞﾌｫﾙﾄ)
                if sync_date > start_day and username.split(" |")[0] not in self.config["hidden_users"]:
                    self.add_row(self.dialog.Global_Leaderboard, username, cards, time, streak, month, retention)

                    if country == self.config["country"].replace(" ", "") and country != "Country":
                        self.add_row(self.dialog.Country_Leaderboard, username, cards, time, streak, month, retention)

                    c_groups = [x.replace(" ", "") for x in self.config["groups"]]
                    if any(i in c_groups for i in groups):
                        self.groups_lb.append([username, cards, time, streak, month, retention, groups, sync_date, start_day])
                        # if self.config["current_group"].replace(" ", "") in groups:
                        if self.config["current_group"] is not None and self.config["current_group"].replace(" ", "") in groups:
                            self.add_row(self.dialog.Custom_Leaderboard, username, cards, time, streak, month, retention)

                    if username.split(" |")[0] in self.config["friends"]:
                        self.add_row(self.dialog.Friends_Leaderboard, username, cards, time, streak, month, retention)

                # 今月のﾘｰﾀﾞｰﾎﾞｰﾄﾞ
                elif sync_date > start_day_minus_thirty and username.split(" |")[0] not in self.config["hidden_users"]:
                    within_one_month_users.append(user_data)

                # ﾌﾚﾝﾄﾞは常に表示する
                elif username.split(" |")[0] in self.config["friends"]:
                    within_one_month_users.append(user_data)

        within_one_month_users.sort(key=lambda x: datetime.datetime.strptime(x[4], '%Y-%m-%d %H:%M:%S.%f'), reverse=True)
        self.login_within_one_month(within_one_month_users, start_day_minus_one)


        self.highlight(self.dialog.Global_Leaderboard)
        self.highlight(self.dialog.Friends_Leaderboard)
        self.highlight(self.dialog.Country_Leaderboard)
        self.highlight(self.dialog.Custom_Leaderboard)


    def set_last_row_items_to_gray(self, leaderbord:QTableWidget, sync_date, start_day):
        # if not IS_ONLINE_DOT:
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

            if YESTERDAY_USERS_GRAY:
                for col in range(1, leaderbord.columnCount()):
                    item = leaderbord.item(row_position, col)
                    if item:
                        if is_today:
                            pass
                            # font = item.font()
                            # font.setBold(True)
                            # item.setFont(font)
                        else:
                            try:
                                from aqt.theme import theme_manager
                                if theme_manager.night_mode:
                                    color_name = "#d2d2d2" #"gray"# "#989898" #"#B0B0B0" "lightgray"
                                else:
                                    color_name = "#2e2e2e" #"gray"
                            except:
                                color_name = "gray"
                            item.setForeground(QColor(color_name))

    # def set_last_row_items_to_gray(self, leaderbord:QTableWidget, sync_date, start_day):
    #     if not YESTERDAY_USERS_GRAY:
    #         return

    #     if not sync_date > start_day:
    #         row_position = leaderbord.rowCount() - 1
    #         for col in range(0, leaderbord.columnCount()):
    #             item = leaderbord.item(row_position, col)
    #             if item:
    #                 try:
    #                     from aqt.theme import theme_manager
    #                     if theme_manager.night_mode:
    #                         color_name = "gray"# "#989898" #"#B0B0B0" "lightgray"
    #                     else:
    #                         color_name = "gray"
    #                 except:
    #                     color_name = "gray"
    #                 item.setForeground(QColor(color_name))


    def login_within_one_month(self, users_list, start_day_minus_one):
        medal_users = self.config["medal_users"]

        for i in users_list:
            username = i[0]
            streak = i[1]
            cards = i[2]
            time = i[3]
            sync_date = i[4]
            sync_date = datetime.datetime.strptime(sync_date, '%Y-%m-%d %H:%M:%S.%f')
            month = i[5]
            groups = []
            if i[6]:
                groups.append(i[6].replace(" ", ""))
            country = i[7]
            retention = i[8]
            if i[9]:
                for group in json.loads(i[9]):
                    groups.append(group)
            groups = [x.replace(" ", "") for x in groups]

            if self.config["show_medals"] == True:
                for i in medal_users:
                    if username in i:
                        username = f"{username} |"
                        if i[1] > 0:
                            username = f"{username} {i[1] if i[1] != 1 else ''}🥇"
                        if i[2] > 0:
                            username = f"{username} {i[2] if i[2] != 1 else ''}🥈"
                        if i[3] > 0:
                            username = f"{username} {i[3] if i[3] != 1 else ''}🥉"

            # 昨日のﾕｰｻﾞｰ
            # if sync_date > start_day_minus_one and username.split(" |")[0] not in self.config["hidden_users"]:
            #     self.add_yesterday_row(self.dialog.Global_Leaderboard, username)

            if country == self.config["country"].replace(" ", "") and country != "Country":
                self.add_yesterday_row(self.dialog.Country_Leaderboard, username)

            c_groups = [x.replace(" ", "") for x in self.config["groups"]]
            if any(i in c_groups for i in groups):
                self.within_one_month_groups_lb.append([username, cards, time, streak, month, retention, groups])
                # if self.config["current_group"].replace(" ", "") in groups:
                if self.config["current_group"] is not None and self.config["current_group"].replace(" ", "") in groups:
                    self.add_yesterday_row(self.dialog.Custom_Leaderboard, username)

            if username.split(" |")[0] in self.config["friends"]:
                self.add_yesterday_row(self.dialog.Friends_Leaderboard, username)



    def add_yesterday_row(self, tab:QTableWidget, username):
        rowPosition = tab.rowCount()
        tab.setColumnCount(7)
        tab.insertRow(rowPosition)

        item = QtWidgets.QTableWidgetItem()
        item.setData(QtCore.Qt.ItemDataRole.DisplayRole, int(rowPosition + 1))
        tab.setItem(rowPosition, 0, item)
        item.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignRight|QtCore.Qt.AlignmentFlag.AlignVCenter)

        tab.setItem(rowPosition, 1, QtWidgets.QTableWidgetItem(str(username)))

        for column in range(2, 7):
            item = QtWidgets.QTableWidgetItem()
            item.setData(QtCore.Qt.ItemDataRole.DisplayRole, "")
            tab.setItem(rowPosition, column, item)
            item.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignRight|QtCore.Qt.AlignmentFlag.AlignVCenter)

        row_position = tab.rowCount() - 1
        for col in range(tab.columnCount()):
            item = tab.item(row_position, col)
            if item:
                item.setForeground(QColor("gray"))

    # def updateTable(self, tab):

    def updateTable(self, tab:QTableWidget, logicalIndex=None, changeGroup=None):
        if logicalIndex in [0, 1, 7, 8]:
            return

        if tab == self.dialog.Custom_Leaderboard and changeGroup:
            self.switchGroup(tab)

            def delay_update_row():
                tab.setSortingEnabled(False)
                self.updateNumbers(tab)
                self.highlight(tab)

                if self.config.get("add_pic_country_and_league", True):
                    from .add_pic_global import add_pic_global_friend_group
                    add_pic_global_friend_group(self, tab, "diamond", "Group")

                    from .change_leaderboard_size import change_board_size
                    change_board_size(self, tab)

                    if self.config.get("gamification_mode", True):
                        from .custom_column import custom_column_size
                        custom_column_size(self, tab)

                # for debug only ------
                from .hide_users_name import hide_all_users_name
                hide_all_users_name(self)
                # ----------------------
                tab.setSortingEnabled(True)

            QTimer.singleShot(0, delay_update_row)

        else:
            if logicalIndex is not None:
                tab.sortItems(logicalIndex, QtCore.Qt.SortOrder.DescendingOrder)
            self.updateNumbers(tab)
            self.highlight(tab)

            if self.config.get("add_pic_country_and_league", True):
                from .change_leaderboard_size import change_size_zero
                change_size_zero(self, tab)


    def updateNumbers(self, tab:QTableWidget):
        rows = tab.rowCount()
        for i in range(0, rows):

            existing_item = tab.item(i, 0)
            icon = None
            if existing_item:
                icon = existing_item.icon()

            item = QtWidgets.QTableWidgetItem()
            item.setData(QtCore.Qt.ItemDataRole.DisplayRole, int(i + 1))

            if icon and not icon.isNull():
                item.setIcon(icon)

            tab.setItem(i, 0, item)
            item.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignRight|QtCore.Qt.AlignmentFlag.AlignVCenter)


    def highlight(self, tab:QTableWidget):

        if not hasattr(self, 'scroll_items'):
            self.scroll_items = []

        for i in range(tab.rowCount()):
            item = tab.item(i, 1).text().split(" |")[0]
            if i % 2 == 0:
                for j in range(tab.columnCount()):
                     
                    try:
                        tab.item(i, j).setBackground(QtGui.QColor(self.colors["ROW_LIGHT"]))
                    except Exception as e:
                        print(f" i:{i}, j:{j}")
                        raise e
                     
            else:
                for j in range(tab.columnCount()):
                    tab.item(i, j).setBackground(QtGui.QColor(self.colors["ROW_DARK"]))
            if item in self.config["friends"] and tab != self.dialog.Friends_Leaderboard:
                for j in range(tab.columnCount()):
                    tab.item(i, j).setBackground(QtGui.QColor(self.colors["FRIEND_COLOR"]))
            if item == self.config["username"]:
                for j in range(tab.columnCount()):
                    tab.item(i, j).setBackground(QtGui.QColor(self.colors["USER_COLOR"]))
            if item == self.config["username"] and self.config["scroll"] == True:
                userposition = tab.item(i, 1)
                tab.selectRow(i)
                # tab.scrollToItem(userposition, QAbstractItemView.ScrollHint.PositionAtCenter)
                self.scroll_items.append((tab, userposition))
                tab.clearSelection()

        if tab.rowCount() >= 3:
            for j in range(tab.columnCount()):
                # tab.item(0, j).setBackground(QtGui.QColor(self.colors["GOLD_COLOR"]))
                # tab.item(1, j).setBackground(QtGui.QColor(self.colors["SILVER_COLOR"]))
                # tab.item(2, j).setBackground(QtGui.QColor(self.colors["BRONZE_COLOR"]))

                self.set_medal_gradient(tab, 0, self.colors["GOLD_COLOR"])
                self.set_medal_gradient(tab, 1, self.colors["SILVER_COLOR"])
                self.set_medal_gradient(tab, 2, self.colors["BRONZE_COLOR"])


    def set_medal_gradient(self, tab:QTableWidget, row:int, base_color:str):

        base_qcolor = QtGui.QColor(base_color)

        lighter_color = QtGui.QColor(base_color)
        lighter_color.setHsv(
            base_qcolor.hue(),
            int(max(0, base_qcolor.saturation() - 20)),
            int(min(255, base_qcolor.value() + 40))
        )

        darker_color = QtGui.QColor(base_color)
        darker_color.setHsv(
            base_qcolor.hue(),
            int(min(255, base_qcolor.saturation() + 10)),
            int(max(0, base_qcolor.value() - 10))
        )

        for j in range(tab.columnCount()):
            item = tab.item(row, j)
            if item:
                gradient = QtGui.QLinearGradient(0, 0, 0, tab.rowHeight(row))
                gradient.setColorAt(0, lighter_color)
                gradient.setColorAt(0.5, base_qcolor)
                gradient.setColorAt(1, darker_color)

                brush = QtGui.QBrush(gradient)
                item.setBackground(brush)



    def user_info(self, tab:QTableWidget):
        for idx in tab.selectionModel().selectedIndexes():
            row = idx.row()
        user_clicked = tab.item(row, 1).text()
        if tab == self.dialog.Custom_Leaderboard:
            enabled = True
        else:
            enabled = False
        mw.shige_user_info = start_user_info(user_clicked, enabled)
        mw.shige_user_info.show()
        mw.shige_user_info.raise_()
        mw.shige_user_info.activateWindow()


    # Friendの検索機能を追加 -------
    def run_serach_users_window(self):
        from .config_search_friends import SearchFriendWindow
        search_window = SearchFriendWindow(self)
        search_window.exec()

    def add_friend_search_button(self):
        self.search_friend_button = QPushButton(self.dialog.tab_2)
        self.search_friend_button.setAutoDefault(False)
        self.search_friend_button.setObjectName("Search Users")
        self.search_friend_button.setText("Search Users")
        self.search_friend_button.clicked.connect(self.run_serach_users_window)

        size_policy = QSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        self.search_friend_button.setSizePolicy(size_policy)

        hbox_layout = QHBoxLayout()
        hbox_layout.addWidget(self.search_friend_button)
        hbox_layout.addStretch()

        # self.dialog.verticalLayout_3.insertWidget(0, self.search_friend_button)
        self.dialog.verticalLayout_3.insertLayout(0, hbox_layout)
    # ------------


    # ﾊﾞｯｸｸﾞﾗｳﾝﾄﾞでｱｸﾃｨﾌﾞﾕｰｻﾞｰ数を取得 ------
    def run_active_users(self):
        # Show active users count

        from .shige_pop.button_manager import mini_button
        self.active_users = f"<span style='font-size: 10pt; font-weight: bold;'>Active users:</span>"
        self.active_users_label = QLabel(self.active_users)
        self.active_users_label.setToolTip("Number of users synced within one month.")

        self.gloabl_extra_layout = QHBoxLayout()
        self.gloabl_extra_layout.addWidget(self.active_users_label)
        self.gloabl_extra_layout.addStretch()

        ### zoom buttons ###
        config = mw.addonManager.getConfig(__name__)
        zoom_enable = config.get("zoom_enable", True)
        if zoom_enable:

            minus_button = QPushButton()
            minus_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            plus_button = QPushButton()
            plus_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)

            leader_boards = [
                [self.dialog.Friends_Leaderboard,"diamond", "Friends"],
                [self.dialog.Country_Leaderboard,"diamond", "Country"],
                [self.dialog.Custom_Leaderboard,"diamond", "Group"],
                [self.dialog.Global_Leaderboard, "hexagon", "Global"],
                [self.dialog.League, "", ""],
            ]

            minus_button.setText(" - ")
            def plus_minus_clicked(value=0.1):
                config = mw.addonManager.getConfig(__name__)
                zoom_value = config.get("size_multiplier", 1.2)
                zoom_value = round(min(max(zoom_value + value, 1.0), 2.0), 1)
                print(zoom_value)
                tooltip(f"Size: {zoom_value}", parent=self)
                write_config("size_multiplier", zoom_value)
                from .change_leaderboard_size import change_board_size
                for tab_widget, icon_type, board_type in leader_boards:
                    change_board_size(self, tab_widget)

            minus_button.clicked.connect(lambda: plus_minus_clicked(-0.1))

            plus_button.setText(" + ")
            plus_button.clicked.connect(lambda: plus_minus_clicked(0.1))

            mini_button(minus_button)
            mini_button(plus_button)

            def run_font_window():
                from .config_set_font_family import  SetFontWindow
                search_window = SetFontWindow(self)
                search_window.show()

            icon = QIcon()
            icon.addPixmap(QPixmap(join(dirname(realpath(__file__)), "designer/icons/settings.png")), QIcon.Mode.Normal, QIcon.State.Off)

            font_button = QPushButton()
            font_button.setIcon(icon)
            font_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            font_button.clicked.connect(run_font_window)
            mini_button(font_button)


            if (config.get("add_pic_country_and_league", True)
                and config.get("gamification_mode", True)
                and config.get("rate_and_donation_buttons", True)):
                rate_button = QPushButton()
                rate_icon =  QIcon(join(dirname(realpath(__file__)), "custom_shige", "icon_good.png"))
                rate_button.setIcon(rate_icon)
                rate_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
                from .shige_pop.popup_config import RATE_THIS_URL
                rate_button.clicked.connect(lambda: openLink(RATE_THIS_URL))
                mini_button(rate_button)

                donation_button = QPushButton()
                heart_icon = QIcon(join(dirname(realpath(__file__)), "custom_shige", "icon_heart.png"))
                donation_button.setIcon(heart_icon)
                donation_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
                donation_button.clicked.connect(lambda: openLink(PATREON_URL))
                mini_button(donation_button)


            self.gloabl_extra_layout.addWidget(minus_button)
            self.gloabl_extra_layout.addWidget(plus_button)
            self.gloabl_extra_layout.addWidget(font_button)
            if (config.get("add_pic_country_and_league", True)
                and config.get("gamification_mode", True)
                and config.get("rate_and_donation_buttons", True)):
                self.gloabl_extra_layout.addWidget(rate_button)
                self.gloabl_extra_layout.addWidget(donation_button)

            ### zoom buttons ###


        # self.dialog.verticalLayout_2.insertWidget(0, self.active_users_label)
        self.dialog.verticalLayout_2.insertLayout(0, self.gloabl_extra_layout)


        op = QueryOp(parent=mw, op=lambda col: self.get_active_users(), success=self.get_active_users_on_success)
        if pointVersion() >= 231000:
            op.without_collection()
        op.run_in_background()

    def get_active_users_on_success(self, result):
        if self.active_users == "":
            return
        try:
            self.active_users_label.setText(self.active_users)
        except RuntimeError:
            return

    def get_active_users(self):
        response = getRequest("active_users/", False)

        if response:
            active_users = response.json().get('active_users', 0)
            active_users_formatted = "{:,}".format(active_users)
            self.active_users = f"<span style='font-size: 10pt; font-weight: bold;'>Active users: {active_users_formatted}</span>"
        else:
            self.active_users = ""
    # -------------------------------------------



    # # ﾊﾞｯｸｸﾞﾗｳﾝﾄﾞでｱｸﾃｨﾌﾞﾕｰｻﾞｰ数を取得 ------
    # def run_active_users(self):
    #     # Show active users count
    #     self.active_users = f"<span style='font-size: 10pt; font-weight: bold;'>Active users:</span>"
    #     self.active_users_label = QLabel(self.active_users)
    #     self.active_users_label.setToolTip("Number of users synced within one month.")
    #     self.dialog.verticalLayout_2.insertWidget(0, self.active_users_label)

    #     op = QueryOp(parent=mw, op=lambda col: self.get_active_users(), success=self.get_active_users_on_success)
    #     if pointVersion() >= 231000:
    #         op.without_collection()
    #     op.run_in_background()

    # def get_active_users_on_success(self, result):
    #     if self.active_users == "":
    #         return
    #     try:
    #         self.active_users_label.setText(self.active_users)
    #     except RuntimeError:
    #         return

    # def get_active_users(self):
    #     response = getRequest("active_users/", False)

    #     if response:
    #         active_users = response.json().get('active_users', 0)
    #         active_users_formatted = "{:,}".format(active_users)
    #         self.active_users = f"<span style='font-size: 10pt; font-weight: bold;'>Active users: {active_users_formatted}</span>"
    #     else:
    #         self.active_users = ""
    # # -------------------------------------------



####

    # def buildLeaderboard(self):

    #     ### CLEAR TABLE ###

    #     self.dialog.Global_Leaderboard.setRowCount(0)
    #     self.dialog.Friends_Leaderboard.setRowCount(0)
    #     self.dialog.Country_Leaderboard.setRowCount(0)
    #     self.dialog.Custom_Leaderboard.setRowCount(0)
    #     self.dialog.League.setRowCount(0)

    #     new_day = datetime.time(int(self.config["newday"]),0,0)
    #     time_now = datetime.datetime.now().time()
    #     if time_now < new_day:
    #         start_day = datetime.datetime.combine(date.today() - timedelta(days=1), new_day)
    #         start_day_minus_thirty = start_day - timedelta(days=30)
    #         start_day_minus_one = start_day - timedelta(days=1)
    #     else:
    #         start_day = datetime.datetime.combine(date.today(), new_day)
    #         start_day_minus_thirty = start_day - timedelta(days=30)
    #         start_day_minus_one = start_day - timedelta(days=1)

    #     # if START_YESTERDAY:
    #     #     start_day = start_day_minus_one

    #     medal_users = self.config["medal_users"]
    #     self.groups_lb = []
    #     self.within_one_month_groups_lb = []
    #     c_groups = [x.replace(" ", "") for x in self.config["groups"]]

    #     within_one_month_users = []

    #     for i in self.response[0]:
    #         user_data = i
    #         username = i[0]
    #         streak = i[1]
    #         cards = i[2]
    #         time = i[3]
    #         sync_date = i[4]
    #         sync_date = datetime.datetime.strptime(sync_date, '%Y-%m-%d %H:%M:%S.%f')
    #         month = i[5]
    #         groups = []
    #         if i[6]:
    #             groups.append(i[6].replace(" ", ""))
    #         country = i[7]
    #         retention = i[8]
    #         if i[9]:
    #             for group in json.loads(i[9]):
    #                 groups.append(group)
    #         groups = [x.replace(" ", "") for x in groups]

    #         if self.config["show_medals"] == True:
    #             for i in medal_users:
    #                 if username in i:
    #                     username = f"{username} |"
    #                     if i[1] > 0:
    #                         username = f"{username} {i[1] if i[1] != 1 else ''}🥇"
    #                     if i[2] > 0:
    #                         username = f"{username} {i[2] if i[2] != 1 else ''}🥈"
    #                     if i[3] > 0:
    #                         username = f"{username} {i[3] if i[3] != 1 else ''}🥉"

    #         # 昨日を計算に含める
    #         if START_YESTERDAY:
    #             if sync_date > start_day_minus_one and username.split(" |")[0] not in self.config["hidden_users"]:
    #                 self.add_row(self.dialog.Global_Leaderboard, username, cards, time, streak, month, retention)
    #                 if not sync_date > start_day:
    #                     self.set_last_row_items_to_gray(self.dialog.Global_Leaderboard)
    #                     row_position = self.dialog.Global_Leaderboard.rowCount() - 1
    #                     for col in range(2, self.dialog.Global_Leaderboard.columnCount()):
    #                         item = self.dialog.Global_Leaderboard.item(row_position, col)
    #                         if item:
    #                             item.setForeground(QColor("gray"))

    #                 if country == self.config["country"].replace(" ", "") and country != "Country":
    #                     self.add_row(self.dialog.Country_Leaderboard, username, cards, time, streak, month, retention)

    #                 c_groups = [x.replace(" ", "") for x in self.config["groups"]]
    #                 if any(i in c_groups for i in groups):
    #                     self.groups_lb.append([username, cards, time, streak, month, retention, groups])
    #                     if self.config["current_group"].replace(" ", "") in groups:
    #                         self.add_row(self.dialog.Custom_Leaderboard, username, cards, time, streak, month, retention)

    #                 if username.split(" |")[0] in self.config["friends"]:
    #                     self.add_row(self.dialog.Friends_Leaderboard, username, cards, time, streak, month, retention)

    #         if sync_date > start_day and username.split(" |")[0] not in self.config["hidden_users"]:
    #             if not START_YESTERDAY:
    #                 self.add_row(self.dialog.Global_Leaderboard, username, cards, time, streak, month, retention)

    #             if country == self.config["country"].replace(" ", "") and country != "Country":
    #                 self.add_row(self.dialog.Country_Leaderboard, username, cards, time, streak, month, retention)

    #             c_groups = [x.replace(" ", "") for x in self.config["groups"]]
    #             if any(i in c_groups for i in groups):
    #                 self.groups_lb.append([username, cards, time, streak, month, retention, groups])
    #                 if self.config["current_group"].replace(" ", "") in groups:
    #                     self.add_row(self.dialog.Custom_Leaderboard, username, cards, time, streak, month, retention)

    #             if username.split(" |")[0] in self.config["friends"]:
    #                 self.add_row(self.dialog.Friends_Leaderboard, username, cards, time, streak, month, retention)


    #         # 今月のﾘｰﾀﾞｰﾎﾞｰﾄﾞを含める
    #         elif sync_date > start_day_minus_thirty and username.split(" |")[0] not in self.config["hidden_users"]:
    #             within_one_month_users.append(user_data)

    #     within_one_month_users.sort(key=lambda x: datetime.datetime.strptime(x[4], '%Y-%m-%d %H:%M:%S.%f'), reverse=True)
    #     self.login_within_one_month(within_one_month_users, start_day_minus_one)


    #     self.highlight(self.dialog.Global_Leaderboard)
    #     self.highlight(self.dialog.Friends_Leaderboard)
    #     self.highlight(self.dialog.Country_Leaderboard)
    #     self.highlight(self.dialog.Custom_Leaderboard)


#####

    # def get_active_users(self):
    #     response = getRequest("active_users/")

    #     if response:
    #         active_users = response.json().get('active_users', 0)
    #         active_users_formatted = "{:,}".format(active_users)
    #         return f"<span style='font-size: 10pt; font-weight: bold;'>Active users: {active_users_formatted}</span>"
    #     else:
    #         return ""