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
from aqt import QColor, mw
from aqt import QLabel, QTableWidget, QVBoxLayout, QHBoxLayout
from .calculate_league import compute_user_rank

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .leaderboardV2 import RebuildLeaderbord, PaginationBoard

class LeagueBoard():
    def __init__(self, rebuild:"RebuildLeaderbord", table_widget: "PaginationBoard"):
        self.rebuild = rebuild

        table_widget.custom_layout.addStretch()
        is_mini_mode = rebuild.config.get("mini_mode", False)

        vbox_layout = QVBoxLayout(table_widget)
        hbox_layout = QHBoxLayout(table_widget)
        vbox_layout.addLayout(hbox_layout)
        table_widget.custom_layout.addLayout(vbox_layout)

        hbox_layout.addStretch()

        ## season label ##
        self.current_season_label = QLabel()
        self.current_season_label.setText(f"<span style='font-size: 10pt;'><b> [ {rebuild.currentSeason} ] </b></span>")
        hbox_layout.addWidget(self.current_season_label)

        ## season info label ##
        self.season_info_label = QLabel()
        time_remaining = rebuild.season_end - datetime.datetime.now()
        tr_days = time_remaining.days
        if tr_days < 0:
            if is_mini_mode:
                diplay_text = "<b>Season End</b>"
            else:
                diplay_text = f"<b>The current season is over, the new season will start next Monday.</b>"

            self.season_info_label.setText(diplay_text)
        else:
            if is_mini_mode:
                diplay_text = f"<b>{tr_days} left</b>"
            else:
                diplay_text = f"<b>{tr_days} days remaining</b>"

            self.season_info_label.setText(diplay_text)
        self.season_info_label.setToolTip(f"Season start: {rebuild.season_start} \nSeason end: {rebuild.season_end} (local time)")

        hbox_layout.addWidget(self.season_info_label)


        # user_score_label = self.make_user_score_label(table_widget)
        # table_widget.custom_layout.addWidget(user_score_label)

        # table_widget.custom_layout.addStretch()

    def make_user_score_label(self, table_widget: "PaginationBoard"): #📍Not used yet
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
            f"{rank_a_f} {percentage_text} "
            f"{global_counter:,} / {table_widget.total_usares:,} "
            "</span>"
            )
        user_score_label.setText(user_score_text)
        return user_score_label


def highlight_league(rebuild:"RebuildLeaderbord", table_widget:QTableWidget, current_page):

    league_name = rebuild.current_league_name
    total_users = rebuild.total_rows

    threshold = int((total_users / 100) * 20)
    target_range_top = range(threshold + 1)
    target_range_buttom = range((total_users - threshold + 1), total_users + 1)

    for row in range(table_widget.rowCount()):

        row_color_type = ""

        rank_number_item = table_widget.item(row, 0)
        if rank_number_item and rank_number_item.text().strip():
            rank_number = int(rank_number_item.text().strip())

            user_name_item = table_widget.item(row, 1)
            if user_name_item:
                user_name = user_name_item.text().split(" |")[0]

                if (not league_name == "Alpha"
                    and rank_number in target_range_top
                    and not user_name in rebuild.config['friends']):
                    row_color_type = 'LEAGUE_TOP'

                if rank_number in target_range_buttom:
                    if not league_name == "Delta" and not user_name in rebuild.config['friends']:
                        row_color_type = 'LEAGUE_BOTTOM'

                if row_color_type:
                    for column in range(table_widget.columnCount()):
                        table_widget.item(row, column).setBackground(QColor(rebuild.colors[row_color_type]))
