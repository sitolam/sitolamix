
import os
from os.path import dirname, join
import re
from aqt import QColor, QCursor, QHeaderView, QIcon, QSize, QTableWidget, QTableWidgetItem, Qt, mw

from .custom_shige.path_manager import ICON_IMAGES_URL

from .check_user_rank import compute_user_rank
from .custom_shige.country_dict import COUNTRY_FLAGS
from .create_icon import create_leaderboard_icon
from .custom_shige.count_time import shigeTaskTimer

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .Leaderboard import start_main

TOOLTIP_ICON_SIZE = 64
LEAGUE_NAMES = ["Delta", "Gamma", "Beta", "Alpha" ]

### GOLOBAL ICONS ###

def add_pic_global_friend_group(self:"start_main", tab_widget:"QTableWidget", icon_type="hexagon", board_type="Today"):

    tab_widget.setColumnCount(7)

    new_column_index = tab_widget.columnCount() # start 1
    tab_widget.setColumnCount(new_column_index + 2) # start 0

    ### global tab ###

    if self.config.get("gamification_mode", True) :
        trophy_item = QTableWidgetItem("🏆Rank")
    else:
        trophy_item = QTableWidgetItem("🏆")

    trophy_item.setToolTip("League")
    tab_widget.setHorizontalHeaderItem(new_column_index, trophy_item) # start 1

    if self.config.get("gamification_mode", True) :
        globe_item = QTableWidgetItem("🌎️Country")
    else:
        globe_item = QTableWidgetItem("🌎️")

    globe_item.setToolTip("Country")
    globe_item.setTextAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
    tab_widget.setHorizontalHeaderItem(new_column_index + 1, globe_item) # start 1

    tab_widget.setColumnWidth(new_column_index + 1, 15)
    tab_widget.horizontalHeader().setSectionResizeMode(new_column_index+1, QHeaderView.ResizeMode.Fixed)

    tab_widget.setColumnWidth(new_column_index, 15)
    tab_widget.horizontalHeader().setSectionResizeMode(new_column_index, QHeaderView.ResizeMode.Fixed)

    total_rows = tab_widget.rowCount()
    country_icons = {}

    self.user_icons_downloader.execution_count = 0

    import time
    total_leaderboard_time = 0
    total_league_time = 0

    for i in range(tab_widget.rowCount()):

    # for i in range(min(tab_widget.rowCount(), 1000)):

        item = tab_widget.item(i, 1).text().split(" |")[0]

        start_leaderboard_time = time.time()
        for leaderbord_lists in self.response[0]:
            if item == leaderbord_lists[0]:
                country = leaderbord_lists[7]

                flag_icon_file_path = COUNTRY_FLAGS.get(country.replace(" ", ""), "pirate.png")
                if flag_icon_file_path == "pirate.png":
                    tooltip_country = "Pirate"
                else:
                    tooltip_country = country

                country_icon = create_leaderboard_icon(file_name=flag_icon_file_path,
                                                    icon_type="flag")

                country_icons[item] = [country_icon, country]

                qtab_c = QTableWidgetItem()
                qtab_c.setIcon(country_icon)
                qtab_c.setText(tooltip_country)
                if not self.config.get("gamification_mode", True):
                    qtab_c.setForeground(QColor(0, 0, 0, 0))

                first_column_item = tab_widget.item(i, 1)
                if first_column_item:
                    qtab_c.setBackground(first_column_item.background())


                qtab_c.setToolTip(f"{tooltip_country}")
                tab_widget.setItem(i, new_column_index+1, qtab_c)

                break

        total_leaderboard_time += time.time() - start_leaderboard_time

        start_league_time = time.time()
        for league_lists in self.response[1]:
            if item == league_lists[0]:
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

                rank_number, rank_a_f, league_percentage_text  = compute_user_rank(i + 1, total_rows)
                new_number = ranks_file_number[rank_number]

                league_icon_filename = league_icons.get(league_name, "delta_04.png").replace("_04", f"_{new_number:02}")

                league_icon = create_leaderboard_icon(file_name=league_icon_filename,
                                                    icon_type=icon_type)
                league_icon_path = league_icon.get_path()


                qtab_le = QTableWidgetItem()
                qtab_le.setIcon(league_icon)

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


                first_column_item = tab_widget.item(i, 1)
                if first_column_item:
                    qtab_le.setBackground(first_column_item.background())

                qtab_le.setToolTip(f"{league_name}")
                tab_widget.setItem(i, new_column_index, qtab_le)

                rank_number, rank_a_f, global_percentage_text  = compute_user_rank(i + 1, total_rows)

                country_icon_Qicon, country_name = country_icons[item]

                if not country_name.replace(" ", "") in COUNTRY_FLAGS:
                    country_name = "Pirate"

                country_icon_path = country_icon_Qicon.get_path()

                header_02 = tab_widget.horizontalHeaderItem(2).text()
                header_03 = tab_widget.horizontalHeaderItem(3).text()
                header_04 = tab_widget.horizontalHeaderItem(4).text()
                header_05 = tab_widget.horizontalHeaderItem(5).text()
                header_06 = tab_widget.horizontalHeaderItem(6).text()

                global_02 = tab_widget.item(i, 2).text()
                global_03 = tab_widget.item(i, 3).text()
                global_04 = tab_widget.item(i, 4).text()
                global_05 = tab_widget.item(i, 5).text()
                global_06 = tab_widget.item(i, 6).text()

                ### SAVE AND LOAD USER TOOLTIP ###

                grade_diff = ""
                rank_diff = ""
                total_diff = ""
                header_02_diff = ""
                header_03_diff = ""
                header_04_diff = ""
                header_05_diff = ""
                header_06_diff = ""

                if (item == self.config["username"]
                    and board_type == "Global"):

                    previous_tooltip = getattr(mw, 'shige_leaderboard_old_user_stats', {})

                    if not isinstance(previous_tooltip, dict):
                        previous_tooltip = {}

                    current_tooltip = {
                        "grade": rank_a_f,
                        "rank": i + 1,
                        "total": total_rows,
                        header_02: global_02,
                        header_03: global_03,
                        header_04: global_04,
                        header_05: global_05,
                        header_06: global_06,
                    }

                    mw.shige_leaderboard_old_user_stats = current_tooltip

                    differences = {}
                    for key in previous_tooltip:
                        if key == "grade":
                            if previous_tooltip[key] != current_tooltip.get(key, ""):
                                differences[key] = previous_tooltip[key]
                            else:
                                differences[key] = ""
                        elif (key in current_tooltip):
                            try:
                                prev_value = float(previous_tooltip[key])
                                curr_value = float(current_tooltip[key])
                                difference = curr_value - prev_value
                                if difference > 0:
                                    differences[key] = f"+{difference:.1f}".rstrip('0').rstrip('.')
                                elif difference < 0:
                                    differences[key] = f"{difference:.1f}".rstrip('0').rstrip('.')
                                else:
                                    differences[key] = ""
                            except ValueError:
                                differences[key] = ""

                    def set_font_color(value):
                        if not value == "":
                            return f'<span style="font-size: 14px;  color: grey;">&nbsp;({value})</span>'
                        else:
                            return value

                    grade_diff = set_font_color(differences.get("grade", ""))
                    rank_diff = set_font_color(differences.get("rank", ""))
                    total_diff = set_font_color(differences.get("total", ""))
                    header_02_diff = set_font_color(differences.get(header_02, ""))
                    header_03_diff = set_font_color(differences.get(header_03, ""))
                    header_04_diff = set_font_color(differences.get(header_04, ""))
                    header_05_diff = set_font_color(differences.get(header_05, ""))
                    header_06_diff = set_font_color(differences.get(header_06, ""))


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
                                <b>{i + 1}{rank_diff}</b> / {total_rows}{total_diff}
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
                                <b>{i + 1}{rank_diff}</b> / {total_rows}{total_diff}
                            </span>
                            <br>
                            <span style="font-size: 12px ;">
                                {global_percentage_text}
                            </span>

                        </td>
                        <td>
                            <span style="font-size: 25px; font-weight: bold;">
                                {item}<br>
                            </span>
                            <img src="{country_icon_path}" width="18" height="18" >
                            <span style="font-size: 20px;">
                                <b>&nbsp;{country_name}</b>
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
                    column_count = tab_widget.columnCount()
                    for column in range(column_count):
                        item = tab_widget.item(i, column)
                        if item is not None:
                            item.setToolTip(text)

                apply_tooltip_to_row(tooltip_text)
                tab_widget.viewport().setCursor(QCursor(Qt.CursorShape.ArrowCursor))

                if self.user_icons_downloader.execution_count < self.user_icons_downloader.max_executions:
                    self.user_icons_downloader.add_make_path_and_icons_list(
                        tab_widget=tab_widget,
                        row_number=i,
                        user_name=item,
                        size=TOOLTIP_ICON_SIZE)
                    self.user_icons_downloader.execution_count += 1

                break

        total_league_time += time.time() - start_league_time

    print(f"Total leaderboard processing time: {total_leaderboard_time:.4f} seconds")
    print(f"Total league processing time: {total_league_time:.4f} seconds")

def add_pic_vs_country(self:"start_main", tab_widget:"QTableWidget"):

    tab_widget.setColumnCount(7)

    country_icons = {}

    self.user_icons_downloader.execution_count = 0

    for i in range(tab_widget.rowCount()):
        country = tab_widget.item(i, 1).text().split(" |")[0]

        flag_icon_file_path = COUNTRY_FLAGS.get(country.replace(" ", ""), "pirate.png")

        country_icon = create_leaderboard_icon(file_name=flag_icon_file_path,
                                            icon_type="flag")

        country_icons[country] = [country_icon, country]
        tab_widget.item(i, 1).setIcon(country_icon)


        def apply_tooltip_to_row(text):
            column_count = tab_widget.columnCount()
            for column in range(column_count):
                item = tab_widget.item(i, column)
                if item is not None:
                    item.setToolTip(text)

        apply_tooltip_to_row("")
        tab_widget.viewport().setCursor(QCursor(Qt.CursorShape.ArrowCursor))