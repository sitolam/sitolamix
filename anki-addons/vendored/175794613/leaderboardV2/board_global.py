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


import os
from os.path import join, dirname, realpath

from aqt import QComboBox, QIcon, QPixmap, QPushButton, Qt, QLabel, QHBoxLayout
from aqt import mw
from aqt.utils import tooltip, openLink
from aqt.operations import QueryOp
from anki.utils import pointVersion

from ..config import write_config
from ..api_connect import getRequest
from ..shige_pop.button_manager import mini_button, mini_button_v3
from ..custom_shige.path_manager import DISCORD_INVITE_URL, PATREON_URL, DISCORD_ICON

from .calculate_league import compute_user_rank
from .mini_mode import set_mini_mode

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from .leaderboardV2 import RebuildLeaderbord, PaginationBoard

class ActiveUsers():
    def __init__(self, rebuild:"RebuildLeaderbord", table_widget: "PaginationBoard"):
        self.table_widget = table_widget
        self.rebuild = rebuild

        # ------- (Left) add buttons -------
        self.active_users = ""
        self.active_users_label = QLabel()
        self.active_users_label.setText(f"<span style='font-size: 10pt;'><b>Active Users:</b></span>")
        self.active_users_label.setToolTip("Number of users synced within one month.")

        table_widget.custom_layout.addWidget(self.active_users_label)

        #📍Under Development
        # user_score_label = self.make_user_score_label(table_widget)
        # table_widget.custom_layout.addWidget(user_score_label)

        from .discord_button import add_discord_button
        add_discord_button(
            table_widget.custom_layout,
            "https://discord.com/channels/1215610525212344350/1215610525904408589",
            "Discord: #general")

        table_widget.custom_layout.addStretch()
        # ------- (Right) add buttons -------

        self.zoom_and_font(table_widget.custom_layout)
        self.rate_this_button(table_widget.custom_layout)

        # -------- (Bottom) add buttons -------

        # self.create_sortby_combobox(self.table_widget.pagination_layout)

        # self.mini_mode_button(self.table_widget.pagination_layout)


        # -------- add buttons end --------
        self.run_active_users()



    def rate_this_button(self, custom_layout:QHBoxLayout):
        config = mw.addonManager.getConfig(__name__)

        # if (config.get("add_pic_country_and_league", True)
        #     and config.get("gamification_mode", True)
        #     and config.get("rate_and_donation_buttons", True)):
        if config.get("rate_and_donation_buttons", True):
            rate_button = QPushButton()
            rate_icon =  QIcon(join(dirname(dirname(realpath(__file__))), "custom_shige", "icon_good.png"))
            rate_button.setIcon(rate_icon)
            rate_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            from ..shige_pop.popup_config import RATE_THIS_URL
            rate_button.clicked.connect(lambda: openLink(RATE_THIS_URL))
            mini_button(rate_button)

            donation_button = QPushButton()
            heart_icon = QIcon(join(dirname(dirname(realpath(__file__))), "custom_shige", "icon_heart.png"))
            donation_button.setIcon(heart_icon)
            donation_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            donation_button.clicked.connect(lambda: openLink(PATREON_URL))
            mini_button(donation_button)

            custom_layout.addWidget(rate_button)
            custom_layout.addWidget(donation_button)


    def zoom_and_font(self, custom_layout:QHBoxLayout):
        ### zoom buttons ###
        config = mw.addonManager.getConfig(__name__)
        zoom_enable = config.get("zoom_enable", True)
        if zoom_enable:

            minus_button = QPushButton()
            minus_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            plus_button = QPushButton()
            plus_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)


            minus_button.setText(" - ")
            def plus_minus_clicked(value=0.1):
                config = mw.addonManager.getConfig(__name__)
                zoom_value = config.get("size_multiplier", 1.2)
                zoom_value = round(min(max(zoom_value + value, 1.0), 2.0), 1)
                print(zoom_value)
                add_text = ""
                if zoom_value == 1.0:
                    add_text = "(min)"
                elif zoom_value == 2.0:
                    add_text = "(max)"
                # tooltip(f"Size: {zoom_value} {add_text}", parent=self.table_widget)
                write_config("size_multiplier", zoom_value)

                self.rebuild.config = mw.addonManager.getConfig(__name__)
                # self.rebuild.set_table_widget_size(self.table_widget.table_widget)
                # self.table_widget.reloadPage()

                self.rebuild.reload_leaderboard()

                tooltip(f"Size: {zoom_value} {add_text}", parent=self.table_widget)

            minus_button.clicked.connect(lambda: plus_minus_clicked(-0.1))

            plus_button.setText(" + ")
            plus_button.clicked.connect(lambda: plus_minus_clicked(0.1))

            mini_button(minus_button)
            mini_button(plus_button)

            def run_font_window():
                from .font_window import  SetFontWindow
                search_window = SetFontWindow(self.rebuild, self.table_widget)
                search_window.show()

            icon = QIcon()
            icon.addPixmap(
                QPixmap(
                    os.path.join(
                    os.path.dirname(os.path.dirname(
                    os.path.realpath(__file__))), "designer/icons/settings.png")),
                    QIcon.Mode.Normal, QIcon.State.Off)

            font_button = QPushButton()
            font_button.setIcon(icon)
            font_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            font_button.clicked.connect(run_font_window)
            mini_button(font_button)

            custom_layout.addWidget(minus_button)
            custom_layout.addWidget(plus_button)
            custom_layout.addWidget(font_button)


    def make_user_score_label(self, table_widget: "PaginationBoard"):
        if table_widget.rebuild.user_score == []:
            return QLabel()

        username, cards, time, streak, month, retention, global_counter, sync_date = table_widget.rebuild.user_score
        user_score_label = QLabel()
        # user_score_text = (
        #     "<span style='font-size: 10pt; font-weight: bold;'>"
        #     f" | Your Rank {global_counter:,} | {cards:,} rev | {time:,} min | {streak:,} streaks | {month:,} rev/31day | {retention} % |"
        #     "</span>")

        rank_number, rank_a_f, percentage_text  = compute_user_rank(global_counter, table_widget.total_usares)

        user_score_text = (
            # "<span style='font-size: 10pt; font-weight: bold;'> "
            "<span style='font-size: 10pt;'> "
            "<b>Your Rank:</b> "
            f"{rank_a_f} "
            f"{global_counter:,} "
            f"{percentage_text} "
            "</span>"
            )
        user_score_label.setText(user_score_text)
        return user_score_label

    def get_active_users(self):
        response = getRequest("active_users/", False)
        if response:
            self.active_users = response.json().get('active_users', 0)
            active_users_formatted = "{:,}".format(self.active_users)
            self.active_users = (
                # "<span style='font-size: 10pt; font-weight: bold;'>"
                "<span style='font-size: 10pt;'>"
                f"<b>Active Users:</b> {active_users_formatted}</span>"
                )

    def get_active_users_on_success(self, result):
        if self.active_users == "":
            return
        try:
            self.active_users_label.setText(self.active_users)
        except RuntimeError:
            return

    def run_active_users(self):
            op = QueryOp(
                parent=mw,
                op=lambda col: self.get_active_users(),
                success=self.get_active_users_on_success)
            if pointVersion() >= 231000:
                op.without_collection()
            op.run_in_background()




        # user_score_text = (
        #     # "<span style='font-size: 10pt; font-weight: bold;'> "
        #     "<span style='font-size: 10pt;'> "
        #     "<b>Your Rank:</b> "
        #     f"{rank_a_f} {percentage_text} "
        #     f"{global_counter:,} / {table_widget.total_usares:,} "
        #     "</span>"
        #     )