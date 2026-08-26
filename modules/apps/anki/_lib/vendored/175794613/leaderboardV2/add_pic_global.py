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
from os.path import dirname, join
import re
from aqt import QColor, QCursor, QHeaderView, QIcon, QSize, QTableWidget, QTableWidgetItem, Qt, mw

from ..custom_shige.path_manager import ICON_IMAGES_URL

from ..check_user_rank import compute_user_rank
from ..custom_shige.country_dict import COUNTRY_FLAGS, COUNTRY_LIST_V2
from ..create_icon import create_leaderboard_icon
from ..custom_shige.count_time import shigeTaskTimer

from .resize_icon import change_icon_size

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .build_bord_v2 import RebuildLeaderbord

TOOLTIP_ICON_SIZE = 64
LEAGUE_NAMES = ["Delta", "Gamma", "Beta", "Alpha" ]


def add_pic_global_friend_group(
    self:"RebuildLeaderbord", table_widget:"QTableWidget", user_item=[], rowPosition=0):

    config = mw.addonManager.getConfig(__name__)

    is_league = False
    is_mini_mode = self.config.get("mini_mode", False)

    if table_widget == self.Global_Leaderboard:
        icon_type = "hexagon"
        board_type = "Global"
    elif table_widget == self.Friends_Leaderboard:
        icon_type = "diamond"
        board_type = "Friends"
    elif table_widget == self.Country_Leaderboard:
        icon_type = "diamond"
        board_type = "Country"
    elif table_widget == self.Custom_Leaderboard:
        icon_type = "diamond"
        board_type = "Group"
    elif table_widget == self.League_Leaderboard:
        icon_type = "shield"
        board_type = "League"
        is_league = True

    total_rows = self.total_rows

    row_number = rowPosition

    column_number_league = 7
    column_number_country = 8

    user_name = user_item[0] # type:str
    
    if user_name == None:
        qtab_c = QTableWidgetItem()
        table_widget.setItem(row_number, column_number_country, qtab_c)

        qtab_le = QTableWidgetItem()
        table_widget.setItem(row_number, column_number_league, qtab_le)
        return

    cards_or_xp = user_item[1]
    time = user_item[2]
    streak = user_item[3]
    month = user_item[4]
    retention = user_item[5]
    rank_counter = user_item[6]
    sync_date = user_item[7]

    country = self.all_users_country_dict.get(user_name.split(" |")[0], "Country") # type:str

    flag_icon_file_path = COUNTRY_FLAGS.get(country.replace(" ", ""), "pirate.png")

    #📍
    display_country_name = COUNTRY_LIST_V2.get(country.replace(" ", ""), "Pirate")

    if flag_icon_file_path == "pirate.png":
        display_country_name = "Pirate"

    country_icon = create_leaderboard_icon(file_name=flag_icon_file_path,
                                        icon_type="flag")

    qtab_c = QTableWidgetItem()
    country_icon_resize = change_icon_size(country_icon, 8)

    qtab_c.setIcon(country_icon_resize)
    self.set_font_and_size_item(qtab_c)

    if is_mini_mode:
        qtab_c.setText("")
    else:
        qtab_c.setText(display_country_name)


    table_widget.setItem(row_number, column_number_country, qtab_c)

    for league_lists in self.response[1]:
        if user_name.split(" |")[0] == league_lists[0]:
            league_name = league_lists[5]

            league_icons = {
            "Delta": "delta_04.png",
            "Gamma": "gamma_04.png",
            "Beta": "beta_04.png",
            "Alpha": "alpha_04.png",
            }

            ranks_file_number = {
                10: 12,
                20: 11,
                30: 10,
                40: 9,
                50: 8,
                60: 7,
                70: 6,
                80: 5,
                90: 2,
                100: 1,
            }

            rank_column_item = table_widget.item(row_number, 0)
            if rank_column_item:
                user_rank = int(rank_column_item.text())

            # rank_number, rank_a_f, league_percentage_text  = compute_user_rank(i + 1, total_rows)
            rank_number, rank_a_f, league_percentage_text  = compute_user_rank(user_rank, total_rows)
            new_number = ranks_file_number[rank_number]

            league_icon_filename = league_icons.get(league_name, "delta_04.png").replace("_04", f"_{new_number:02}")

            league_icon = create_leaderboard_icon(file_name=league_icon_filename,
                                                icon_type=icon_type)
            league_icon_path = league_icon.get_path()

            qtab_le = QTableWidgetItem()
            self.set_font_and_size_item(qtab_le)

            league_icon_resize = change_icon_size(league_icon, 7)
            qtab_le.setIcon(league_icon_resize)

            if is_mini_mode:
                qtab_le.setText(f"")
            else:
                qtab_le.setText(f" {rank_a_f} ")

            if not self.config.get("gamification_mode", True):
                qtab_le.setForeground(QColor(0, 0, 0, 0))

            league_icon_path = league_icon.get_path()

            star_icon = create_leaderboard_icon(file_name="star_icon.png", icon_type="other")
            star_icon_img = f'<img src="{star_icon.get_path()}" width="20" height="20" >'

            league_stars = {
            "Delta": f'{star_icon_img}',
            "Gamma": f'{star_icon_img*2}',
            "Beta": f'{star_icon_img*3}',
            "Alpha": f'{star_icon_img*4}',
            }

            # qtab_le.setToolTip(f"{league_name}")
            table_widget.setItem(row_number, column_number_league, qtab_le)

            rank_number, rank_a_f, global_percentage_text  = compute_user_rank(user_rank, total_rows)

            country_icon_path = country_icon.get_path()

            if is_league:
                header_02 = "XP"
                header_03 = "Time"
                header_04 = "Reviews"
                header_05 = "Retention"
                header_06 = "DaysStudied"
            else:
                header_02 = "Reviews"
                header_03 = "Time"
                header_04 = "Streak"
                header_05 = "Past 31days"
                header_06 = "Retention"

            global_02 = cards_or_xp
            global_03 = time
            global_04 = streak
            global_05 = month
            global_06 = retention

            ### SAVE AND LOAD USER TOOLTIP ###

            grade_diff = ""
            rank_diff = ""
            total_diff = ""
            header_02_diff = ""
            header_03_diff = ""
            header_04_diff = ""
            header_05_diff = ""
            header_06_diff = ""

            if (user_name.split(" |")[0] == config["username"] and board_type == "Global"):

                previous_tooltip = getattr(mw, 'shige_leaderboard_old_user_stats', {})

                if not isinstance(previous_tooltip, dict):
                    previous_tooltip = {}

                current_tooltip = {
                    "grade": rank_a_f,
                    "rank": rank_counter + 1,
                    "total": total_rows,
                    header_02: global_02,
                    header_03: global_03,
                    header_04: global_04,
                    header_05: global_05,
                    header_06: global_06,
                }

                mw.shige_leaderboard_old_user_stats = current_tooltip

                score_differences = {}
                for key in previous_tooltip:
                    if key == "grade":
                        if previous_tooltip[key] != current_tooltip.get(key, ""):
                            score_differences[key] = previous_tooltip[key]
                        else:
                            score_differences[key] = ""
                    elif (key in current_tooltip):
                        try:
                            prev_value = float(previous_tooltip[key])
                            curr_value = float(current_tooltip[key])
                            difference = curr_value - prev_value
                            if difference > 0:
                                score_differences[key] = f"+{difference:.1f}".rstrip('0').rstrip('.')
                            elif difference < 0:
                                score_differences[key] = f"{difference:.1f}".rstrip('0').rstrip('.')
                            else:
                                score_differences[key] = ""
                        except ValueError:
                            score_differences[key] = ""

                def set_font_color(value):
                    if not value == "":
                        return f'<span style="font-size: 14px;  color: grey;">&nbsp;({value})</span>'
                    else:
                        return value

                grade_diff = set_font_color(score_differences.get("grade", ""))
                rank_diff = set_font_color(score_differences.get("rank", ""))
                total_diff = set_font_color(score_differences.get("total", ""))
                header_02_diff = set_font_color(score_differences.get(header_02, ""))
                header_03_diff = set_font_color(score_differences.get(header_03, ""))
                header_04_diff = set_font_color(score_differences.get(header_04, ""))
                header_05_diff = set_font_color(score_differences.get(header_05, ""))
                header_06_diff = set_font_color(score_differences.get(header_06, ""))

                self.now_your_stats_tooltip = f"""
                <table cellpadding="10">
                    <tr>
                        <td align="center">
                            <img src="{league_icon_path}" width="{TOOLTIP_ICON_SIZE}" height="{TOOLTIP_ICON_SIZE}">
                                <br>
                                {league_stars[league_name]}
                            <span style="font-size: 14px; font-weight: bold;">
                                <br>
                                {league_name.upper()}
                        </td>
                        <td>

                        <span style="font-size: 14px; font-weight: bold;">
                                Your grade in {board_type} for now:
                            </span>
                        <br>
                            <span style="font-size: 25px; font-weight: bold;">
                            {rank_a_f}
                            </span>{grade_diff}
                        <br>
                        <span style="font-size: 25px; ">
                            <b>{user_rank}{rank_diff}</b> / {total_rows}{total_diff}
                        </span>
                        <br>
                        <span style="font-size: 20px; font-weight: bold;">
                            {global_percentage_text}
                        </span>
                    </tr>
                </table>
                """

            #### GLOBAL TOOLTIP ###

            tooltip_text = f"""
            <table cellpadding="10">
                <tr>
                    <td align="center">
                        <!--PLACEHOLDER-->
                        <img src="{league_icon_path}" width="{TOOLTIP_ICON_SIZE}" height="{TOOLTIP_ICON_SIZE}">
                        <br>
                        <span style="font-size: 16px; font-weight: bold;">
                            {league_stars[league_name]}
                            <br>
                            {league_name.upper()}
                            <br>
                            <span style="font-size: 16px; font-weight: bold;">

                                {board_type} :&nbsp;{rank_a_f}{grade_diff}
                            </span>
                        </span>
                        <br>
                        <span style="font-size: 16px; ">
                            <b>{user_rank}{rank_diff}</b> / {total_rows}{total_diff}
                        </span>
                        <br>
                        <span style="font-size: 12px ;">
                            {global_percentage_text}
                        </span>

                    </td>
                    <td>
                        <span style="font-size: 25px; font-weight: bold;">
                            {user_name}<br>
                        </span>
                        <img src="{country_icon_path}" width="18" height="18" >
                        <span style="font-size: 20px;">
                            <b>&nbsp;{country}</b>
                        </span>
                        <span style="font-size: 16px;">
                            <br>
                            {header_02} : <b>{global_02}</b>&nbsp;{header_02_diff}<br>
                            {header_03} : <b>{global_03}</b>&nbsp;{header_03_diff}<br>
                            {header_04} : <b>{global_04}</b>&nbsp;{header_04_diff}<br>
                            {header_05} : <b>{global_05}</b>&nbsp;{header_05_diff}<br>
                            {header_06} : <b>{global_06}</b>&nbsp;{header_06_diff}<br>
                        </span>
                        <span style="font-size: 12px; color: grey;">
                            Double click on user for more info.
                        </span>
                    </td>
                </tr>
            </table>
            """

            def apply_tooltip_to_row(text):
                column_count = table_widget.columnCount()
                for column in range(column_count):
                    item = table_widget.item(row_number, column)
                    if item is not None:
                        item.setToolTip(text)

            apply_tooltip_to_row(tooltip_text)

            # if self.config.get("add_pic_country_and_league", True):
            if True:
                if self.user_icons_downloader.execution_count < self.user_icons_downloader.max_executions:
                    self.user_icons_downloader.add_make_path_and_icons_list(
                        tab_widget=table_widget,
                        row_number=row_number,
                        user_name=user_name.split(" |")[0],
                        size=TOOLTIP_ICON_SIZE)
                    self.user_icons_downloader.execution_count += 1

            break
