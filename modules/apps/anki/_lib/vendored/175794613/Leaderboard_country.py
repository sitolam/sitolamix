import datetime
from datetime import date, timedelta
import json
from aqt import  QColor, QComboBox, QHBoxLayout, QIcon, QPushButton, QSizePolicy, QTableWidget, Qt, mw

from .custom_shige.country_dict import COUNTRY_LIST


from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .Leaderboard import start_main


# 国の追加機能 --------------
class CountryLeaderbord:
    def __init__(self, start_main: 'start_main'):
        self.start_main = start_main
        self.sorted_country_data = {}

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
            groups.append(user_data[6].replace(" ", ""))
        country = user_data[7]
        retention = user_data[8]
        if user_data[9]:
            for group in json.loads(user_data[9]):
                groups.append(group)
        groups = [x.replace(" ", "") for x in groups]

        if self.start_main.config["show_medals"] == True:
            medal_users = self.start_main.config["medal_users"]
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
        new_day = datetime.time(int(self.start_main.config["newday"]), 0, 0)
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


    def rebuild_country_leaderboard(self, new_country:str, text_color=True):

        ### CLEAR TABLE ###
        self.start_main.dialog.Country_Leaderboard.setRowCount(0)

        (start_day, start_day_minus_thirty, start_day_minus_one
            ) = self.calculate_dates(1) # 昨日を含む

        if new_country == self.start_main.config["country"].replace(" ", ""):
            start_day_minus_one = start_day # 自国は昨日の値を表示しない

        within_one_month_users = []

        for item in self.start_main.response[0]:
            user_data = item

            (username, streak, cards, time, sync_date, month, groups, country, retention
                ) = self.extract_user_data(item)


            # 時差を考慮して昨日を計算に含める
            if sync_date > start_day_minus_one and username.split(" |")[0] not in self.start_main.config["hidden_users"]:
                if country == new_country.replace(" ", "") and country != "Country":
                    self.start_main.add_row(self.start_main.dialog.Country_Leaderboard, username, cards, time, streak, month, retention)
                     
                    # text_color = False
                    if text_color:
                        # self.set_row_gray(self.start_main.dialog.Country_Leaderboard, sync_date, start_day)
                        self.start_main.set_last_row_items_to_gray(self.start_main.dialog.Country_Leaderboard, sync_date, start_day)

            # 今月のﾘｰﾀﾞｰﾎﾞｰﾄﾞ
            elif sync_date > start_day_minus_thirty and username.split(" |")[0] not in self.start_main.config["hidden_users"]:
                within_one_month_users.append(user_data)

        within_one_month_users.sort(key=lambda x: datetime.datetime.strptime(x[4], '%Y-%m-%d %H:%M:%S.%f'), reverse=True)
        for one_month_item in within_one_month_users:
            username = one_month_item[0]
            country = one_month_item[7]
            if country == new_country.replace(" ", "") and country != "Country":
                self.start_main.add_yesterday_row(self.start_main.dialog.Country_Leaderboard, username)


    def vs_country_leaderboard(self, get_data_only=False):

        ### CLEAR TABLE ###
        if not get_data_only:
            self.start_main.dialog.Country_Leaderboard.setRowCount(0)

        (start_day, start_day_minus_thirty, start_day_minus_one
            ) = self.calculate_dates(6) # 過去7日間

        country_data = {}

        for item in self.start_main.response[0]:
            user_data = item


            (username, streak, cards, time, sync_date, month, groups, country, retention
                ) = self.extract_user_data(item)

            # 時差を考慮して昨日を計算に含める
            if sync_date > start_day_minus_one:
            # if sync_date > start_day_minus_one and username.split(" |")[0] not in self.start_main.config["hidden_users"]:

                if country not in country_data:
                    country_data[country] = {
                        "cards": 0,
                        "time": 0.0,
                        "streak": 0,
                        "month": 0,
                        "retention": 0.0,
                        "total_users": 0
                    }
                country_data[country]["cards"] += int(cards)
                country_data[country]["time"] += float(time)
                country_data[country]["streak"] += int(streak)
                country_data[country]["month"] += int(month)
                country_data[country]["retention"] += float(retention)
                country_data[country]["total_users"] += 1

            elif sync_date > start_day_minus_thirty:

                if country not in country_data:
                    country_data[country] = {
                        "cards": 0,
                        "time": 0.0,
                        "streak": 0,
                        "month": 0,
                        "retention": 0.0,
                        "total_users": 0
                    }
                country_data[country]["total_users"] += 1


        for c_data_item in list(country_data.keys()):
            for default_country in COUNTRY_LIST:
                if c_data_item.replace(" ", "") == default_country.replace(" ", ""):
                    break
            else:
                del country_data[c_data_item]

        # cardsの値が高い順にｿｰﾄ
        self.sorted_country_data = sorted(country_data.items(), key=lambda item: item[1]["month"], reverse=True)

        if not get_data_only:
            for index, (country, data) in enumerate(self.sorted_country_data):

                medal = ""
                if (index + 1) == 1:
                    medal = "🥇"
                elif (index + 1) == 2:
                    medal = "🥈"
                elif (index + 1) == 3:
                    medal = "🥉"

                active_users = data.get("total_users", 0)
                active_users = f"{medal} {active_users} users"

                display_name = f"{country} |{active_users}"

                self.start_main.add_row(
                    self.start_main.dialog.Country_Leaderboard,
                    display_name, data["cards"], data["time"],
                    data["streak"], data["month"], data["retention"]
                )
                self.vs_country_set_row_gray(self.start_main.dialog.Country_Leaderboard)


    def vs_country_set_row_gray(self, leaderbord: QTableWidget):
        row_position = leaderbord.rowCount() - 1
        for col in range(0, leaderbord.columnCount()):
            if col in [2, 3, 4, 6]:
                item = leaderbord.item(row_position, col)
                if item:
                    item.setForeground(QColor("gray"))

    def set_row_gray(self, leaderbord:QTableWidget, sync_date, start_day):
        if not sync_date > start_day:
            row_position = leaderbord.rowCount() - 1
            for col in range(0, leaderbord.columnCount()):
                item = leaderbord.item(row_position, col)
                if item:
                    item.setForeground(QColor("gray"))


    def custom_highlight(self, tab: QTableWidget):
        if not hasattr(self.start_main, 'scroll_items'):
            self.start_main.scroll_items = []

        for i in range(tab.rowCount()):
            item = tab.item(i, 1).text().split(" |")[0]
            if i % 2 == 0:
                tab.item(i, 0).setBackground(QColor(self.start_main.colors["ROW_LIGHT"]))
            else:
                tab.item(i, 0).setBackground(QColor(self.start_main.colors["ROW_DARK"]))

            if item in self.start_main.config["friends"] and tab != self.start_main.dialog.Friends_Leaderboard:
                tab.item(i, 0).setBackground(QColor(self.start_main.colors["FRIEND_COLOR"]))

            if item == self.start_main.config["username"]:
                tab.item(i, 0).setBackground(QColor(self.start_main.colors["USER_COLOR"]))

            if item == self.start_main.config["username"] and self.start_main.config["scroll"] == True:
                userposition = tab.item(i, 1)
                tab.selectRow(i)
                self.start_main.scroll_items.append((tab, userposition))
                tab.clearSelection()

        # if tab.rowCount() >= 3:
        #     tab.item(0, 0).setBackground(QColor(self.start_main.colors["GOLD_COLOR"]))
        #     tab.item(1, 0).setBackground(QColor(self.start_main.colors["SILVER_COLOR"]))
        #     tab.item(2, 0).setBackground(QColor(self.start_main.colors["BRONZE_COLOR"]))


    def custom_updateTable(self, tab:QTableWidget, logicalIndex=None):
        if logicalIndex is not None:
            tab.sortItems(logicalIndex, Qt.SortOrder.DescendingOrder)

            self.start_main.updateNumbers(tab)
            self.custom_highlight(tab)


    def on_country_changed(self, index=None):
        if index is None:
            index = self.country_search_input.currentIndex()

        tab = self.start_main.dialog.Country_Leaderboard
        selected_country = self.country_search_input.itemData(index)

        tab.setSortingEnabled(False)
        self.rebuild_country_leaderboard(selected_country)
        # tab.sortItems(5, Qt.SortOrder.DescendingOrder)
        tab.setSortingEnabled(False) # updateTableで処理するのでいらない

        header3 = tab.horizontalHeader()
        try:
            header3.sectionClicked.disconnect()
        except TypeError:
            pass

        self.start_main.updateNumbers(tab)

        if selected_country == self.start_main.config["country"].replace(" ", ""):
            self.start_main.highlight(tab)
            header3.sectionClicked.connect(lambda logicalIndex: self.start_main.updateTable(tab, logicalIndex))
        else:
            # self.custom_highlight(tab)
             
            self.start_main.highlight(tab)
             
            header3.sectionClicked.connect(lambda logicalIndex: self.custom_updateTable(tab, logicalIndex))


        try:
            tab.doubleClicked.disconnect()
        except TypeError:
            pass

        tab.doubleClicked.connect(lambda: self.start_main.user_info(tab))
        tab.setToolTip("Double click on user for more info.")

        if self.start_main.config.get("add_pic_country_and_league", True):
            from .add_pic_global import add_pic_global_friend_group
            add_pic_global_friend_group(self.start_main, self.start_main.dialog.Country_Leaderboard, "diamond", "Country")


        from .change_leaderboard_size import change_board_size
        change_board_size(self.start_main, tab)

        # for debug only ------
        from .hide_users_name import hide_all_users_name
        hide_all_users_name(self.start_main)

         
        if (self.start_main.config.get("add_pic_country_and_league", True)
            and self.start_main.config.get("gamification_mode", True)):
            from .custom_column import custom_column_size
            custom_column_size(self.start_main, tab)


    def open_country(self, tab:QTableWidget):
        if not tab == self.start_main.dialog.Country_Leaderboard:
            return
        for idx in tab.selectionModel().selectedIndexes():
            row = idx.row()
        user_clicked = tab.item(row, 1).text().split(" |")[0]
        # index = self.country_search_input.findText(user_clicked)
        index = self.country_search_input.findData(user_clicked)
        if index != -1:
            self.country_search_input.setCurrentIndex(index)
            self.on_country_changed(index)



    def on_vs_country_leaderboard(self):
        tab = self.start_main.dialog.Country_Leaderboard
        tab.setSortingEnabled(False)
        self.vs_country_leaderboard()
        tab.setSortingEnabled(False)


        header3 = tab.horizontalHeader()
        try:
            header3.sectionClicked.disconnect()
        except TypeError:
            pass


        self.start_main.updateNumbers(tab)
        self.start_main.highlight(tab)

        for i in range(tab.rowCount()):
            item = tab.item(i, 1).text().split(" |")[0]
            if item == self.start_main.config["country"].replace(" ", ""):
                for j in range(tab.columnCount()):
                    tab.item(i, j).setBackground(QColor(self.start_main.colors["USER_COLOR"]))

        try:
            tab.doubleClicked.disconnect()
        except TypeError:
            pass

        tab.doubleClicked.connect(lambda: self.open_country(tab))
        tab.setToolTip("Double click to open country leaderboard.")

        if self.start_main.config.get("add_pic_country_and_league", True):
            from .add_pic_global import add_pic_vs_country
            add_pic_vs_country(self.start_main, tab)


        from .change_leaderboard_size import change_board_size
        change_board_size(self.start_main, tab)

        # for debug only ------
        from .hide_users_name import hide_all_users_name
        hide_all_users_name(self.start_main)

         
        # tab.setSortingEnabled(False)
        # if self.start_main.config.get("gamification_mode", True):
        #     from .custom_column import custom_column_size
        #     custom_column_size(self.start_main, tab)
        # tab.setSortingEnabled(True)



    def run_set_country_window(self):
        from .config_set_country import SetCountryWindow
        country_window = SetCountryWindow(self.start_main)
        country_window.exec()

    def get_country_time(self, country):
        try:
            import sys
            import os
            import importlib.util

            if 'tzdata' not in sys.modules:
                addon_root = os.path.dirname(os.path.abspath(__file__))
                tzdata_source = os.path.join(addon_root, 'bundle', 'tzdata', '__init__.py')
                spec = importlib.util.spec_from_file_location('tzdata', tzdata_source)
                module = importlib.util.module_from_spec(spec)
                sys.modules['tzdata'] = module
                spec.loader.exec_module(module)
        except Exception as e:
            print(f"Error importing tzdata: {e}")
            return ""

        if 'tzdata' in sys.modules:
            pass
        else:
            print("Failed to import tzdata")


        try:
            from zoneinfo import ZoneInfo
        except Exception as e:
            print(f"Error importing ZoneInfo: {e}")
            return ""

        # pip install --target="C:\Users\shigg\AppData\Roaming\Anki2\addons21\Anki Leaderboard (Fixed by Shige)\bundle\tzdata" tzdata

        try:
            from .custom_shige.country_dict import COUNTRY_TIMEZONES
        except Exception as e:
            print(f"Error importing COUNTRY_TIMEZONES: {e}")
            return ""

        timezone = COUNTRY_TIMEZONES.get(country, "")
        if timezone == "":
            print(f"Timezone not found for country: {country}")
            return ""

        try:
            timezone = ZoneInfo(timezone)
            current_time = datetime.datetime.now(timezone)
            # formatted_time = current_time.strftime('%m/%d %Hh')
            # formatted_time = current_time.strftime('%b-%d-%I%p')
            # formatted_time = current_time.strftime('%b-%d-%a-%I%p')
            # formatted_time = current_time.strftime('%b %d %a %I %p')
            # formatted_time = current_time.strftime('%d-%Hh')
            # formatted_time = current_time.strftime('%b-%d-%a-%I%p')
            # formatted_time = current_time.strftime('%I %p')
            formatted_time = current_time.strftime('%H:%M')
            
            hours, minutes = map(int, formatted_time.split(':'))
            if 18 <= hours or hours < 5:
                formatted_time += "🌙"
            else:
                formatted_time += "☀️"
            
            
            return formatted_time
        except Exception as e:
            print(f"Error getting current time for timezone {timezone}: {e}")
            return ""


    def add_set_country_button(self):
        from .custom_shige.country_dict import COUNTRY_FLAGS
        from .create_icon import create_leaderboard_icon
        hbox_layout = QHBoxLayout()

        config = mw.addonManager.getConfig(__name__)
        from .custom_shige.searchable_combobox import SearchableComboBox
        self.country_search_input = SearchableComboBox(self.start_main)
        self.country_search_input.setSizeAdjustPolicy(QComboBox.SizeAdjustPolicy.AdjustToContents)
        self.country_search_input.setMaxVisibleItems(20)

        self.vs_country_leaderboard(get_data_only=True)
        self.sorted_country_data : "list"

        if not self.sorted_country_data:
            for i in COUNTRY_LIST:
                self.country_search_input.addItem(i.replace(" ", ""))
        else:
            for index, (country, data) in enumerate(self.sorted_country_data):
                medal = ""
                if (index + 1) == 1:
                    medal = "🥇"
                elif (index + 1) == 2:
                    medal = "🥈"
                elif (index + 1) == 3:
                    medal = "🥉"

                country_time = self.get_country_time(country)

                active_users = ""
                active_users = data.get("total_users", 0)
                month = data.get("month", 0)
                if isinstance(month, int):
                    month = f"{month:,}"
                country_score = f"| {active_users} users | {month} rev | {country_time} "

                display_name = f"{medal}{index + 1}. {country.replace(' ', '')} {country_score}"
                flag_icon_file_path = COUNTRY_FLAGS.get(country.replace(" ", ""), "pirate.png")
                country_icon = create_leaderboard_icon(file_name=flag_icon_file_path,
                                                    icon_type="flag")
                self.country_search_input.addItem(country_icon, display_name, country.replace(' ', ''))
        country = config.get("country", "Country")

        if country not in COUNTRY_LIST:
            country = "Country"
        # self.country_search_input.setCurrentText(country)

        index = self.country_search_input.findData(country.replace(" ", ""))
        if index != -1:
            self.country_search_input.setCurrentIndex(index)

        self.country_search_input.currentIndexChanged.connect(self.on_country_changed)
        self.country_search_input.lineEdit().returnPressed.connect(self.on_country_changed)

        # self.country_search_input.currentTextChanged.connect(lambda: self.update_country_table(self.dialog.Country_Leaderboard))


        hbox_layout.addWidget(self.country_search_input)


        self.vs_country_button = QPushButton(self.start_main.dialog.tab_3)
        self.vs_country_button.setAutoDefault(False)
        self.vs_country_button.setObjectName("VS Countries")
        self.vs_country_button.setText("VS Countries")
        self.vs_country_button.clicked.connect(self.on_vs_country_leaderboard)
        size_policy = QSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        self.vs_country_button.setSizePolicy(size_policy)
        hbox_layout.addWidget(self.vs_country_button)





        if country == "Country":
            self.set_country_button = QPushButton(self.start_main.dialog.tab_3)
            self.set_country_button.setAutoDefault(False)
            self.set_country_button.setObjectName("Select your Country")
            self.set_country_button.setText("Select your Country")
            self.set_country_button.clicked.connect(self.run_set_country_window)
            size_policy = QSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
            self.set_country_button.setSizePolicy(size_policy)
            hbox_layout.addWidget(self.set_country_button)

        hbox_layout.addStretch()

        self.start_main.dialog.verticalLayout_4.insertLayout(0, hbox_layout)
    # ------------------------------
