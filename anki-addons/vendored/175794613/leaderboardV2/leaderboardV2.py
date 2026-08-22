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


import math
import os
import sys
from aqt.qt import (QWidget, QHBoxLayout,
                            QVBoxLayout, QPushButton, QComboBox, QTableWidget,
                            QTabWidget, QSizePolicy)
from aqt.qt import Qt

from aqt import QCloseEvent, QIcon, QLabel, QListView, QMoveEvent, QPixmap, QResizeEvent, QScrollBar, QTimer, mw

from ..config_manager import write_config

from ..custom_shige.searchable_combobox import SearchableComboBox
from ..custom_shige.rate_limit_timer import rate_limit
from ..shige_pop.button_manager import mini_button_v2

from .custom_qtable_widget import QTableWidgetV2 as QTableWidget

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .build_bord_v2 import RebuildLeaderbord

import uuid


class LeaderBoardV2(QWidget):
    def __init__(self, rebuild:"RebuildLeaderbord", parent=None):

        self.config = mw.addonManager.getConfig(__name__)
        is_allways_on_top = self.config.get("allways_on_top", False)
        if is_allways_on_top:
            parent = None

        super().__init__(parent)
        self.setWindowFlag(Qt.WindowType.Window)

        if is_allways_on_top:
            self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint)

        self.is_save_zoom = False

        self.rebuild_board = rebuild

        rebuild.Global_Leaderboard
        rebuild.Friends_Leaderboard
        rebuild.Country_Leaderboard
        rebuild.Custom_Leaderboard
        rebuild.League_Leaderboard

        self.setWindowTitle("Anki Leaderboard V2 Custom by Shigeඞ")

        icon = QIcon()
        icon.addPixmap(QPixmap(
            os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))),
                        "designer/icons/krone.png")),
                        QIcon.Mode.Normal, QIcon.State.Off)
        self.setWindowIcon(icon)

        # sat board size
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

            self.setMinimumSize(200, 200)

            board_position = self.config.get("board_position", [])
            if (board_position and len(board_position) == 2
                and isinstance(board_position[0], int) and isinstance(board_position[1], int)
                and board_position[0] > 0 and board_position[1] > 0):
                self.move(board_position[0], board_position[1])


        main_layout = QVBoxLayout(self)
        self.setLayout(main_layout)

        self.tab_widget = QTabWidget()
        main_layout.addWidget(self.tab_widget)

        from .add_options import create_sortby_combobox, add_mini_mode_button

        ### Global ###
        self.global_page = tab_content = PaginationBoard(
            rebuild.Global_Leaderboard, rebuild.global_cache,
            rebuild.page_size, rebuild)
        self.tab_widget.addTab(tab_content, "Global") #📍Translate
        from .board_global import ActiveUsers
        self.active_users = ActiveUsers(rebuild, tab_content)
        add_mini_mode_button(rebuild, tab_content)
        create_sortby_combobox(tab_content.pagination_layout)

        ### Friends ###
        self.friend_page = tab_content = PaginationBoard(
            rebuild.Friends_Leaderboard, rebuild.friends_cache,
            rebuild.page_size, rebuild)
        self.tab_widget.addTab(tab_content, "Friends")
        from .board_friends import FriendBoard
        self.friend_board = FriendBoard(tab_content)
        add_mini_mode_button(rebuild, tab_content)
        create_sortby_combobox(tab_content.pagination_layout)

        ### Country ###
        self.country_page = tab_content = PaginationBoard(
            rebuild.Country_Leaderboard, rebuild.country_cache,
            rebuild.page_size, rebuild)
        self.tab_widget.addTab(tab_content, "Country")
        from .toggle_country import set_toggle_country
        set_toggle_country(rebuild, tab_content)
        from .board_country import CountryBoard
        self.counrty_board = CountryBoard(tab_content)
        add_mini_mode_button(rebuild, tab_content)
        create_sortby_combobox(tab_content.pagination_layout)

        ### Group ###
        current_group = self.config.get("current_group", []) #type: str
        if current_group:
            rebuild.groups_cache = rebuild.all_groups_cache.get(current_group.replace(" ", ""), [])

        self.group_page = tab_content = PaginationBoard(
            rebuild.Custom_Leaderboard, rebuild.groups_cache,
            rebuild.page_size, rebuild)
        self.tab_widget.addTab(tab_content, "Group")

        from .toggle_groups import set_toggle_groups
        set_toggle_groups(rebuild, tab_content)

        add_mini_mode_button(rebuild, tab_content)
        create_sortby_combobox(tab_content.pagination_layout)

        ### League ###
        user_league = rebuild.calculate_league.user_league_name
        rebuild.league_cache = rebuild.calculate_league.get_cache(user_league)
        rebuild.current_league_name = user_league

        self.league_page = tab_content = PaginationBoard(
            rebuild.League_Leaderboard, rebuild.league_cache,
            rebuild.page_size, rebuild)
        self.tab_widget.addTab(tab_content, "League")
        from .toggle_league import set_toggle_league
        set_toggle_league(rebuild, tab_content, user_league)
        from .board_league import LeagueBoard
        self.league_board = LeagueBoard(rebuild, tab_content)

        self.tab_widget.setCurrentIndex(self.config["tab"])

        add_mini_mode_button(rebuild, tab_content)


        self.is_save_zoom = True
        # self.show()
        

        

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

    def closeEvent(self, event: QCloseEvent):
        if hasattr(self.rebuild_board, "user_icons_downloader"):
            self.rebuild_board.user_icons_downloader.stop_download_flag = True

        super().closeEvent(event)


    def keyPressEvent(self, event):
        if event.key() == Qt.Key.Key_Escape:  # Esc
            self.close()
        else:
            super().keyPressEvent(event)




class PaginationBoard(QWidget):
    def __init__(self, tabale_widget:"QTableWidget",
                leaderboard_cache, page_size, rebuild:"RebuildLeaderbord"):
        super().__init__()
        self.table_widget = tabale_widget

        # self.table_widget.is_auto_scroll = False
        # self.table_widget.is_auto_scroll_top = False
        # self.table_widget.processed_pages = set()
        # self.table_widget.user_row_number = 0

        self.rebuild = rebuild
        self.page_size = 0
        self.total_usares = 0
        self.uuid = str(uuid.uuid4())
        self.is_scroll_connected = False

        self.auto_load_page = True

        self.config = mw.addonManager.getConfig(__name__)

        self.tab_layout = QVBoxLayout(self)
        self.setLayout(self.tab_layout)

        self.custom_layout = QHBoxLayout()
        self.custom_layout.addWidget(QLabel(""))

        self.table_layout = QHBoxLayout()

        self.pagination_layout = QHBoxLayout()

        self.connect_and_disconect_scroll(True)

        self.initPagination(leaderboard_cache, page_size)

    def onScroll(self, value):
        if not self.auto_load_page:
            return
        scroll_bar = self.table_widget.verticalScrollBar()
        # QScrollBar
        if value == scroll_bar.maximum():
            self.table_widget.is_auto_scroll = True
            self.onScrollToBottom()
        elif value == 0:
            self.table_widget.is_auto_scroll = True
            self.table_widget.is_auto_scroll_top = True
            self.onScrollToTop()

    def connect_and_disconect_scroll(self, connect=True):
        if not self.auto_load_page:
            return
        try:
            if connect and not self.is_scroll_connected:
                self.table_widget.verticalScrollBar().valueChanged.connect(self.onScroll)
                self.is_scroll_connected = True
            elif not connect and self.is_scroll_connected:
                self.table_widget.verticalScrollBar().valueChanged.disconnect(self.onScroll)
                self.is_scroll_connected = False
        except Exception as e:
            print(f"Error in connect_and_disconnect_scroll: {e}")

    def onScrollToBottom(self):
        if rate_limit.limit(f"onScroll_{self.uuid}", 2):
            self.table_widget.is_auto_scroll = False
            self.table_widget.is_auto_scroll_top = False
            return
        print("Scrolled to bottom")
        self.goToNextPageByScroll()
        self.table_widget.is_auto_scroll = False

    def onScrollToTop(self):
        if rate_limit.limit(f"onScroll_{self.uuid}", 2):
            self.table_widget.is_auto_scroll = False
            self.table_widget.is_auto_scroll_top = False
            return
        print("Scrolled to top")
        self.goToPrevPageByScroll()
        self.table_widget.is_auto_scroll = False
        self.table_widget.is_auto_scroll_top = False

    def initPagination(self, leaderboard_cache, page_size):
        # ﾍﾟｰｼﾞﾈｰｼｮﾝの状態管理
        self.page_size = page_size
        max_rows = math.ceil(max(1, len(leaderboard_cache) / page_size))
        self.total_usares = max(0, len(leaderboard_cache))
        self.total_pages = max_rows # 総ﾍﾟｰｼﾞ数

        # is_mini_mode = self.config.get("mini_mode", False)
        is_mini_mode = True

        self.current_page = 1 # 現在のﾍﾟｰｼﾞ
        if self.config["scroll"] == True:
            self.current_page = self.calculate_user_page()

        # navigation
        # first_page_btn_text = '1 <<'

        if is_mini_mode:
            first_page_btn_text = "Top<"
        else:
            first_page_btn_text = "Top <<"

        self.first_page_btn = QPushButton(first_page_btn_text)
        mini_button_v2(self.first_page_btn)
        self.prev_page_btn = QPushButton('<')
        mini_button_v2(self.prev_page_btn)

        # page number buttons (6 buttons)
        self.page_buttons = []
        for i in range(6):
            btn = QPushButton(str(i+1))
            self.page_buttons.append(btn)

        # navigation
        self.next_page_btn = QPushButton('>')
        mini_button_v2(self.next_page_btn)
        self.last_page_btn = QPushButton(f'>> {self.total_usares}')
        mini_button_v2(self.last_page_btn)
        if is_mini_mode:
            self.last_page_btn.setVisible(False)
        else:
            self.last_page_btn.setVisible(True)

        if is_mini_mode:
            user_page_text = "You"
        else:
            user_page_text = "Your Score"

        self.user_page_btn = QPushButton(user_page_text)
        mini_button_v2(self.user_page_btn)

        # ﾍﾟｰｼﾞ選択ｺﾝﾎﾞﾎﾞｯｸｽ
        self.page_combo = QComboBox()
        self.page_combo.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        # self.page_combo.setEditable(False)
        # list_view = QListView()
        # list_view.setFixedHeight(200)
        # self.page_combo.setView(list_view)

        for i in range(1, self.total_pages + 1):
            page_number = self.calculate_display_page(i)
            self.page_combo.addItem(f" {page_number} ")

        self.pagination_layout.addWidget(self.first_page_btn)
        self.pagination_layout.addWidget(self.prev_page_btn)

        for btn in self.page_buttons:
            self.pagination_layout.addWidget(btn)

        self.pagination_layout.addWidget(self.next_page_btn)
        self.pagination_layout.addWidget(self.last_page_btn)

        self.pagination_layout.addWidget(self.page_combo)
        self.pagination_layout.addWidget(self.user_page_btn)
        self.pagination_layout.addStretch()

        self.tab_layout.addLayout(self.custom_layout)

        self.table_layout.addWidget(self.table_widget)
        self.tab_layout.addLayout(self.table_layout)

        self.tab_layout.addLayout(self.pagination_layout)

        self.user_page_btn.clicked.connect(self.goToUserPage)

        self.first_page_btn.clicked.connect(self.goToFirstPageByButton)
        # self.prev_page_btn.clicked.connect(self.goToPrevPage)
        self.prev_page_btn.clicked.connect(self.goToPrevPageByButton)
        self.next_page_btn.clicked.connect(self.goToNextPage)
        self.last_page_btn.clicked.connect(self.goToLastPage)

        for i, btn in enumerate(self.page_buttons):
            btn:QPushButton
            btn.clicked.connect(lambda _, idx=i: self.onPageButtonClicked(idx))

        self.page_combo.currentIndexChanged.connect(self.onComboBoxChanged)

        self.updatePageButtons()
        self.loadPage(self.current_page)
        self.table_widget.processed_pages.add(self.current_page)


    def calculate_user_page(self):
        user_page_number = 0
        if self.table_widget == self.rebuild.Global_Leaderboard:
            user_page_number = self.rebuild.user_rank_global

        elif self.table_widget == self.rebuild.Friends_Leaderboard:
            user_page_number = self.rebuild.user_rank_friends

        elif self.table_widget == self.rebuild.Country_Leaderboard:
            user_page_number = self.rebuild.user_rank_country

        elif self.table_widget == self.rebuild.Custom_Leaderboard:
            current_group = self.config.get("current_group", [])
            if current_group:
                user_page_number = self.rebuild.user_rank_groups.get(current_group, 0)

        elif self.table_widget == self.rebuild.League_Leaderboard:
            if self.rebuild.current_league_name == self.rebuild.calculate_league.user_league_name:
                user_page_number = self.rebuild.user_rank_league

        if user_page_number:
            user_page_number = math.ceil(user_page_number / self.page_size)

        if not user_page_number:
            user_page_number = 1

        return user_page_number


    def resetPagination(self, leaderboard_cache, page_size):
        # Clear existing layout
        while self.pagination_layout.count():
            item = self.pagination_layout.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()

        self.initPagination(leaderboard_cache, page_size)

    def calculate_display_page(self, page_number):
        display_page = max(1, (max(1, page_number) * self.page_size) - self.page_size)
        return str(display_page)


    def updatePageButtons(self):
        # 現ﾍﾟｰｼﾞを中心に表示
        if self.current_page <= 3:
            start_page = 1
        elif self.current_page >= self.total_pages - 2:
            start_page = max(1, self.total_pages - 5)
        else:
            # 現ﾍﾟｰｼﾞを中央に調整
            start_page = self.current_page - 2

        # is_mini_mode = self.config.get("mini_mode", False)
        is_mini_mode = True

        for i in range(6):
            page_num = start_page + i
            real_page_num = self.current_page + i
            is_blue = False
            page_button = self.page_buttons[i] #type:QPushButton
            if page_num <= self.total_pages:
                page_button.setText(self.calculate_display_page(page_num))
                page_button.setEnabled(True)
                page_button.setProperty("page_num", page_num)

                # BlueButton
                if page_num == self.current_page:
                    page_button.setStyleSheet("background-color: lightblue;")
                    is_blue = True
                else:
                    page_button.setStyleSheet("")
            else:
                page_button.setText(" ")
                page_button.setEnabled(False)
                page_button.setProperty("page_num", None)
            mini_button_v2(page_button, is_blue)

            if is_mini_mode:
                page_button.setVisible(False)
            else:
                page_button.setVisible(True)


    def loadPage(self, page):
        # self.table_widget.verticalScrollBar().blockSignals(True)
        self.connect_and_disconect_scroll(False)
        self.current_page = page

        self.page_combo.blockSignals(True)
        self.page_combo.setCurrentIndex(page - 1)  # ｺﾝﾎﾞﾎﾞｯｸｽも更新
        self.page_combo.blockSignals(False)
        self.page_combo.setSizeAdjustPolicy(QComboBox.SizeAdjustPolicy.AdjustToContents)
        self.page_combo.setMinimumContentsLength(5)
        self.page_combo.setMaximumWidth(200)

        
        ### add row items ###
        self.rebuild.update_row_items(self.table_widget, page)
        # self.rebuild.pagination_board.show()

        self.table_widget.update()
        self.table_widget.repaint()

        self.updatePageButtons()
        
        QTimer.singleShot(500, lambda: self.connect_and_disconect_scroll(True))
        # self.connect_and_disconect_scroll(True)
        # self.table_widget.verticalScrollBar().blockSignals(False)


    def goToUserPage(self):
        self.previous_page = False
        self.table_widget.manually_top = False
        self.table_widget.manually_scroll = True
        self.current_page = self.calculate_user_page()
        self.table_widget.processed_pages = set()
        self.table_widget.processed_pages.add(self.current_page)
        self.loadPage(self.current_page)

    def reloadPage(self):
        self.table_widget.manually_top = False
        self.table_widget.manually_scroll = False
        self.previous_page = False
        self.table_widget.processed_pages = set()
        self.table_widget.processed_pages.add(self.current_page)
        self.loadPage(self.current_page)


    def goToFirstPageByButton(self):
        self.table_widget.manually_top = True
        self.table_widget.manually_scroll = False
        self.previous_page = False
        self.table_widget.processed_pages = set()
        self.table_widget.processed_pages.add(1)
        self.loadPage(1)


    def goToFirstPage(self):
        self.table_widget.manually_top = False
        self.table_widget.manually_scroll = False
        self.previous_page = False
        self.table_widget.processed_pages = set()
        self.table_widget.processed_pages.add(1)
        self.loadPage(1)

    def goToPrevPageByScroll(self):
        if self.current_page > 1:
            for next_page in range(self.current_page - 1, 0, -1):
                if next_page not in self.table_widget.processed_pages:
                    self.table_widget.processed_pages.add(next_page)
                    self.rebuild.previous_page = True
                    self.table_widget.manually_top = False
                    self.table_widget.manually_scroll = False
                    self.loadPage(next_page)
                    return
        self.previous_page = False
        self.table_widget.manually_top = False
        self.table_widget.manually_scroll = False


    def goToNextPageByScroll(self):
        if self.current_page < self.total_pages:
            for next_page in range(self.current_page + 1, self.total_pages + 1):
                if next_page not in self.table_widget.processed_pages:
                    self.table_widget.processed_pages.add(next_page)
                    self.previous_page = False
                    self.table_widget.manually_top = False
                    self.table_widget.manually_scroll = False
                    self.loadPage(next_page)
                    return

    def goToPrevPageByButton(self):
        if self.current_page > 1:
            self.previous_page = False
            self.table_widget.manually_top = False
            self.table_widget.manually_scroll = False
            self.table_widget.processed_pages = set()
            self.table_widget.processed_pages.add(self.current_page - 1)
            self.loadPage(self.current_page - 1)

    def goToNextPage(self): #📍
        if self.current_page < self.total_pages:
            self.previous_page = False
            self.table_widget.manually_top = False
            self.table_widget.manually_scroll = False
            self.table_widget.processed_pages = set()
            self.table_widget.processed_pages.add(self.current_page + 1)
            self.loadPage(self.current_page + 1)

    def goToLastPage(self):
        self.previous_page = False
        self.table_widget.manually_top = False
        self.table_widget.manually_scroll = False
        self.table_widget.processed_pages = set()
        self.table_widget.processed_pages.add(self.total_pages)
        self.loadPage(self.total_pages)

    def onPageButtonClicked(self, button_idx):
        page_button = self.page_buttons[button_idx] # type:QPushButton
        # page_number = int(page_button.text())
        page_number = page_button.property("page_num")
        if page_number:
            self.previous_page = False
            self.table_widget.manually_top = False
            self.table_widget.manually_scroll = False
            self.table_widget.processed_pages = set()
            self.table_widget.processed_pages.add(page_number)
            self.loadPage(page_number)

    def onComboBoxChanged(self, index):
        if index >= 0:
            self.table_widget.processed_pages = set()
            self.table_widget.processed_pages.add(index + 1)
            self.table_widget.manually_top = False
            self.table_widget.manually_scroll = False
            self.loadPage(index + 1)


