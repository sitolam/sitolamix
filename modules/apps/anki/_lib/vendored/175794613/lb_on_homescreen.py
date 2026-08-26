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

import html
import json
import datetime
import time as d_time
from datetime import date, timedelta

from aqt import mw, gui_hooks
from anki.hooks import wrap
from aqt.operations import QueryOp
from anki.utils import pointVersion
from aqt.deckbrowser import DeckBrowser, DeckBrowserContent

try:
    from PyQt6.QtGui import QColor
except:
    from aqt.qt import QColor

from .userInfo import start_user_info
from .config_manager import write_config
from .config_local import get_local_config, save_local_config
from .custom_shige.country_dict import COUNTRY_LIST_V2

from .icon_downloader_home import home_icon_downloader

from .path_manager import ADDON_NAME
from .custom_shige.path_manager import LEADERBOAD_ICON
from .lb_home_v2.now_loading_checker import ID_SHIGE_SYNC_LOADING_ICON
from .lb_home_v2.lb_home_tools import (
    make_icon_html, add_align_middle, make_multiple_box,
    make_checkbox_mini, make_checkbox_normal,
    set_gamification_mode
    )


data = None

USER_ICON_SIZE = 30
SHIGE_LB_CONTAINER = "shige-lb-container"

COLOR_ALPHA = 0.6

cache_board_data = {}
cache_user_data_sub = {}


def get_cache_board_data():
    return cache_board_data

def get_cache_user_data_sub():
    return cache_user_data_sub


#MARK:tools

def add_align_middle(text):
    return f'<span style="vertical-align: middle;">{text}</span>'

def hex_color_to_rgba(hex_color, alpha):
    color = QColor(hex_color)
    red = color.red()
    green = color.green()
    blue = color.blue()
    return f"rgba({red},{green},{blue},{alpha})"


def make_lb_box_css():
    try:
        from aqt.theme import theme_manager
        nightmode = theme_manager.night_mode
    except:
        nightmode = False

    if nightmode:
        str_background_color = "rgba(54, 54, 54, 0.8)"
        str_text_color = "#fcfcfc"
    else:
        str_background_color = "rgba(255, 255, 255, 0.8)"
        str_text_color = "#020202"

    # <span class="shige_lb_box_text">
    box_text_css = f"""
<style>
.shige_lb_box_text {{
    display: inline-block;
    border-radius: 4px;
    background-color: {str_background_color};
    color: {str_text_color};
    padding: 1px 4px;
    text-align: center;
    margin: 2px 2px;
}}
</style>
"""

    return box_text_css





#MARK:re-sort

def re_sort_leaderboard_data(sort_type):
    global data

    start_time = d_time.time()

    sort_key_index = {
        "Streak": 1,
        "Reviews": 2,
        "Time": 3,
        "31days": 5,
        "Retention": 8,
    }

    if sort_type not in sort_key_index:
        print("[Leaderboard] Error sort type:", sort_type)
        return

    index_to_sort = sort_key_index[sort_type]

    try:
        sorted_list = []
        for item in data[0]:
            if item[index_to_sort] is not None:
                sort_value = item[index_to_sort]
            else:
                sort_value = 0
            sorted_list.append((sort_value, item))

        sorted_list.sort(reverse=True, key=lambda x: x[0])

        new_data_list = []
        for pair in sorted_list:
            new_data_list.append(pair[1])

        data[0] = new_data_list

    except Exception as error:
        print("[Leaderboard] Error:", error)


    elapsed = d_time.time() - start_time
    print(f"[{ADDON_NAME}] re-sort: {elapsed:.4f} sec")


#MARK:getData

def getData():
    global cache_board_data, cache_user_data_sub
    cache_board_data = {}
    cache_user_data_sub = {}

    config = mw.addonManager.getConfig(__name__)
    medal_users = config["medal_users"]

    user_league_name = "Delta"

    lo_config = get_local_config()
    current_mode = lo_config.get("lb_home_mode", "Game")
    home_selected_league = lo_config.get("home_selected_league")
    home_selected_country = lo_config.get("home_selected_country")


    is_legacy_mode = False
    if current_mode == "Legacy":
        is_legacy_mode = True


    # --- save leagues ----
    start_time = d_time.time()
    for item in data[1]:
        username = item[0]
        league_name = item[5]

        username_split = username.split(" |")[0]

        cache_user_data = cache_user_data_sub.setdefault(username_split, []) # type: list

        index = 0
        if len(cache_user_data) < index + 1 :
            cache_user_data.append(league_name)
        else:
            cache_user_data[index] = league_name

        if config["username"] == username:
            user_league_name = league_name
            cache_board_data["user_league_name"] = user_league_name

    elapsed = d_time.time() - start_time
    # print(f"[{ADDON_NAME}] save leagues: {elapsed:.6f} sec")
    # ----------------------

    # --- save country ----
    start_time = d_time.time()

    for item in data[0]:
        username = item[0]
        country = item[7]

        username_split = username.split(" |")[0]

        cache_user_data = cache_user_data_sub.setdefault(username_split, []) # type: list

        index = 1
        if len(cache_user_data) < index + 1:
            while len(cache_user_data) < index + 1:
                cache_user_data.append(None)
            cache_user_data[index] = country
        else:
            cache_user_data[index] = country

    elapsed = d_time.time() - start_time
    # print(f"[{ADDON_NAME}] save country: {elapsed:.6f} sec")
    # ----------------------


    #MARK:data-global
    if config["tab"] != 4:

        new_day = datetime.time(int(config['newday']), 0, 0)
        time_now = datetime.datetime.now().time()
        if time_now < new_day:
            start_day = datetime.datetime.combine(date.today() - timedelta(days=1), new_day)
        else:
            start_day = datetime.datetime.combine(date.today(), new_day)

        from .lb_home_v2.calculate_country import country_data_manager
        country_data_manager.reset_country_data()

        start_day_minus_seven = start_day - timedelta(days=6)
        start_day_minus_thirty = start_day - timedelta(days=30)

        ## today or yesterday
        if not is_legacy_mode and config.get("start_yesterday", True):
            start_day_minus_one = start_day - timedelta(days=1)
            start_today_or_yesterday = start_day_minus_one
        else:
            start_today_or_yesterday = start_day

        lb_list = []
        counter = 0


        if home_selected_country and home_selected_country in COUNTRY_LIST_V2.keys():
            user_country = home_selected_country

        else:
            user_country = config["country"].replace(" ", "")
            if user_country not in COUNTRY_LIST_V2.keys():
                user_country = "NoSetCountry"


        list_one_month_users = []

        for item in data[0]:
            username = item[0] #type: str
            streak = item[1]
            cards = item[2]
            time = item[3]
            sync_date = item[4]
            sync_date = datetime.datetime.strptime(sync_date, '%Y-%m-%d %H:%M:%S.%f')
            month = item[5]
            country = item[7]
            retention = item[8]
            groups = []

            username_split = username.split(" |")[0]

            if item[6]:
                groups.append(item[6].replace(" ", ""))
            if item[9]:
                for group in json.loads(item[9]):
                    groups.append(group)
            groups = [x.replace(" ", "") for x in groups]

            if config["show_medals"] == True:
                for item in medal_users:
                    if username in item:
                        username = f"{username} |"
                        if item[1] > 0:
                            username = f"{username} {item[1] if item[1] != 1 else ''}🥇"
                        if item[2] > 0:
                            username = f"{username} {item[2] if item[2] != 1 else ''}🥈"
                        if item[3] > 0:
                            username = f"{username} {item[3] if item[3] != 1 else ''}🥉"

            if sync_date > start_today_or_yesterday and username_split not in config["hidden_users"]:
            # if sync_date > start_day and username not in config["hidden_users"]:
                if config["tab"] == 0:
                    counter += 1
                    lb_list.append([counter, username, cards, time, streak, month, retention, country])

                if config["tab"] == 1 and username_split in config["friends"]:
                    counter += 1
                    lb_list.append([counter, username, cards, time, streak, month, retention, country])

                # if config["tab"] == 2 and country == config["country"].replace(" ", ""):
                if config["tab"] == 2 and country == user_country:
                    counter += 1
                    lb_list.append([counter, username, cards, time, streak, month, retention, country])

                if config["tab"] == 3 and config["current_group"] is not None and config["current_group"].replace(" ", "") in groups:
                    counter += 1
                    lb_list.append([counter, username, cards, time, streak, month, retention, country])


                if sync_date > start_day:
                    cache_user_data = cache_user_data_sub.setdefault(username, []) # type: list
                    index = 2
                    sync_today = True
                    if len(cache_user_data) < index + 1:
                        while len(cache_user_data) < index + 1:
                            cache_user_data.append(None)
                        cache_user_data[index] = sync_today
                    else:
                        cache_user_data[index] = sync_today

            # 30 days+
            elif sync_date > start_day_minus_thirty and username_split not in config["hidden_users"]:
                if not is_legacy_mode and (
                    (config["tab"] == 1 and username_split in config["friends"])
                    or (config["tab"] == 2 and country == user_country)
                    or (config["tab"] == 3 and config["current_group"] is not None
                            and config["current_group"].replace(" ", "") in groups)):
                    list_one_month_users.append([username, sync_date, country])

            if sync_date > start_day_minus_thirty and username_split not in config["hidden_users"]:
                country_data_manager.save_country_data(country, sync_date, month, start_day_minus_seven)

        if list_one_month_users:
            list_one_month_users.sort(key=lambda item: item[1], reverse=True)
            for m_item in list_one_month_users:
                counter += 1
                username = m_item[0]
                cards = 0
                time = 0
                streak = 0
                month = 0
                retention = 0
                country = m_item[2]
                lb_list.append([counter, username, cards, time, streak, month, retention, country])

        cache_board_data["board_total_user"] = counter

    #MARK:data-league
    if config["tab"] == 4:

        if home_selected_league:
            user_league_name = home_selected_league

        counter = 0
        lb_list = []
        for item in data[1]:

            username = item[0]
            xp = item[1]
            time_spend = item[2]
            reviews = item[3]
            retention = item[4]
            league_name = item[5]
            # history = item[6]
            days_learned = item[7]

            username_split = username.split(" |")[0]

            for item in medal_users:
                if username in item:
                    username = f"{username} |"
                    if item[1] > 0:
                        username = f"{username} {item[1] if item[1] != 1 else ''}🥇"
                    if item[2] > 0:
                        username = f"{username} {item[2] if item[2] != 1 else ''}🥈"
                    if item[3] > 0:
                        username = f"{username} {item[3] if item[3] != 1 else ''}🥉"

            if league_name == user_league_name and xp != 0:
                counter += 1
                if username_split not in config["hidden_users"]:
                    lb_list.append([counter, username, xp, time_spend, reviews, retention, days_learned])

        cache_board_data["league_total_user"] = counter

    write_config("homescreen_data", lb_list)
    return lb_list



#MARK:hook

def on_deck_browser_will_render_content(overview, content:DeckBrowserContent):
    # print(f"[{ADDON_NAME}] > on_deck_browser_will_render_content")
    try:
        config = mw.addonManager.getConfig(__name__)

        lo_config = get_local_config()
        force_show_home_leaderboard = lo_config.get("force_show_home_leaderboard", True)
        if not force_show_home_leaderboard:
            return

        if config["homescreen"] == False:
            str_show_home = "show-home-Leaderboard"
            str_show_home = make_show_home_checkbox(
                                text=str_show_home,
                                mini_mode=True)
            str_show_home = (
                f'<center>'
                f'<div id="shige-lb-mini" style="padding: 5px;">'
                f'{str_show_home}'
                f'</div>'
                f'</center>'
                )

            content.stats += str_show_home

            return

        # ----------------------------

        # print(f"[{ADDON_NAME}] >> content.stats")

        str_now_loading = ""

        if not lo_config.get("lb_home_mode", "Game") == "Legacy":

            box_text_css = make_lb_box_css()

            leaderbaord_icon = make_icon_html(LEADERBOAD_ICON, 30)
            leaderbaord_icon = add_align_middle(leaderbaord_icon)

            loading_text = ""
            # if loading_checker():
            from .lb_home_v2.now_loading_checker import make_loading_icon
            loading_icon_html = make_loading_icon()
            loading_icon_html = add_align_middle(loading_icon_html)
            loading_text = f'<span id="shige_lb_now_loading_text">: Now Loading...{loading_icon_html}</span>'

            if config.get("username", "") == "" or not config.get("authToken"):
                str_sync_or_join = "[sync/join]"
            else:
                str_sync_or_join = "[sync]"


            str_sync_button = f"""\
<a style="cursor: pointer; font-size:12px;" onclick="pycmd('shige_leaderboard_sync_or_join')">{str_sync_or_join}</a>"""

            str_now_loading = (
                f'{box_text_css}'
                f'<span class="shige_lb_box_text">'
                f'{leaderbaord_icon}'
                f' Anki Leaderboard {str_sync_button} '
                f'{loading_text}'

                # f'<span id="shige_lb_now_loading_text">Now Loading...{loading_icon_html}</span>'
                # f'Anki Leaderboard: Now Loading...{loading_icon_html}'
                # f'🏆️Anki Leaderboard: Now Loading...{loading_icon_html}'
                f'</span>'
            )


        content.stats += (
        f'<div id="{SHIGE_LB_CONTAINER}">'
        f'{str_now_loading}'
        f'</div>'
        )

        if data == None:
            return

        make_home_leaderboard()


    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")


#MARK:QueryOp

def make_home_leaderboard():
    # Rearrange home addonsの互換性を追加 ---
    if data == None:
        return True

    config = mw.addonManager.getConfig(__name__)
    if config["homescreen"] == False:
        return False
    # ----------------------------

    on_query_op_home_board()

    return True


def on_query_op_home_board():
    from .custom_shige.delay_start_timer import delay_start_timer
    delay_start_timer.need_delay_start(_on_query_op_home_board)


is_now_loading = False

def check_is_now_loading():
    return is_now_loading

def check_legacy_mode():
    try:
        lo_config = get_local_config()
        lb_home_mode = lo_config.get("lb_home_mode", "Game")
        if lb_home_mode == "Legacy":
            return True
        else:
            return False

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")
        return True # Legacy

def _on_query_op_home_board():
    global is_now_loading
    if is_now_loading:
        print(f"[{ADDON_NAME}] _on_query_op_home_board: Now loading... ")
        return

    is_now_loading = True

    try:
        from .lb_home_v2.now_loading_checker import start_loading_timer
        start_loading_timer()
    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

    try:
        if home_icon_downloader and not check_legacy_mode():
            home_icon_downloader.check_icon_dict_exists()
            home_icon_downloader.stop_download_flag = True
            home_icon_downloader.list_need_dl_icon_pack = []
    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")


    op = QueryOp(parent=mw,
        op=lambda col: _make_home_leaderboard(),
        success=on_home_board_success
        )
    if pointVersion() >= 231000:
        op.without_collection()

    op.failure(on_failure)

    op.run_in_background()


def on_failure(failure, *args, **kwargs):
    global is_now_loading
    is_now_loading = False
    print(f"[{ADDON_NAME}] Error, _on_query_op_home_board:\n\n {failure}\n\n")


def on_home_board_success(result):
    global is_now_loading
    try:
        is_now_loading = False
        if isinstance(result, str):
            on_refresh_home_board(result_html=result)
            # print(f"[{ADDON_NAME}] > on_home_board_success")
            if home_icon_downloader and not check_legacy_mode():
                home_icon_downloader.is_running = False
                home_icon_downloader.stop_download_flag = False
                home_icon_downloader.request_dl_v2()
        else:
            print(f"[{ADDON_NAME}] Error, on_home_board_success:\n\n {result}\n\n")

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")


def _make_home_leaderboard():
    config = mw.addonManager.getConfig(__name__)

    from .lb_home_v2.calculate_display_text import make_global_display_text, make_league_display_text

    lo_config = get_local_config()

    current_mode = lo_config.get("lb_home_mode", "Game")
    zoom_scale = lo_config.get("zoom_scale", 1.0)
    font_size = lo_config.get("font_size", 15)
    hide_other_users = lo_config.get("hide_other_users", False)


    max_users_v2 = lo_config.get("max_users_v2", 10)
    manually_user_index = lo_config.get("manually_user_index")

    gamification_mode = config.get("gamification_mode", True)
    set_gamification_mode(gamification_mode)
    add_pic_country_and_league = config.get("add_pic_country_and_league", True)



    is_mini_mode = False
    is_legacy_mode = False
    if current_mode == "Legacy":
        is_legacy_mode = True
    elif current_mode == "V2_mini":
        is_mini_mode = True

    if config["homescreen_data"]:
        lb = config["homescreen_data"]
    else:
        lb = getData()


    #MARK:table
    if is_legacy_mode:
        add_new_style = """
        font-weight: bold;
        """
        padding_px = "padding: 8px;"
    else:
        add_new_style = """
            overflow: hidden;
            """
        padding_px = "padding: 3px;"


    try:
        from aqt.theme import theme_manager
        nightmode = theme_manager.night_mode
    except:
        nightmode = False

    if nightmode:
        str_background_color = "rgba(54, 54, 54, 0.8)"
        str_background_color_02 = "rgba(100, 100, 100, 1.0)"
        str_text_color = "#fcfcfc"
        str_text_blue = "#93c5fd" #"#3b82f6"
        str_boder_color = "#252525"
        str_background_bover = "rgba(37, 37, 37, 0.9)"
        str_row_even = "rgba(60, 60, 60, 0.5)"
        str_row_odd = "rgba(48, 48, 48, 0.5)"

    else:
        str_background_color = "rgba(255, 255, 255, 0.8)"
        str_background_color_02 = "rgba(255, 255, 255, 1.0)"
        str_text_color = "#020202"
        str_text_blue = "#93c5fd"
        str_boder_color = "#e4e4e4"
        str_background_bover = "rgba(228, 228, 228, 0.9)"
        str_row_even = "rgba(245, 245, 245, 0.5)"
        str_row_odd = "rgba(255, 255, 255, 0.5)"

    if is_legacy_mode:
        str_border_radius = 0
        str_blur_px = ""

    else:
        str_border_radius = 30
        # str_blur_px = "backdrop-filter: blur(5px);"
        str_blur_px = ""

    str_svg_color = str_text_color.replace("#", "%23")

    # table.lb_table tr {{
    #     transition: background-color 0.2s, color 0.2s;
    # }}

    #MARK:CSS
    #border-collapse: collapse;
    table_style = f"""
<style>
    :host, :host * {{
        color: {str_text_color};
        font-size: {font_size}px;
    }}

    table.lb_table {{
        font-family: arial, sans-serif;
        width: 35%;
        margin-left:auto;
        margin-right:auto;
        {add_new_style}

        background-color: {str_background_color};
        background-size: cover;

        color: {str_text_color};
        box-shadow:
            0px 0px 3px 1px rgba(20,20,20,0.08),
            0px 2px 6px 1px rgba(20,20,20,0.08),
            0px 1px 3px 1px rgba(20,20,20,0.08);

        border: 1px solid {str_boder_color};
        border-radius: 12px;

        border-collapse: collapse;
        {str_blur_px}

        transform: scale({zoom_scale});
        transform-origin: left top;

    }}

    table.lb_table td{{
        white-space: nowrap;
    }}

    table.lb_table td, th {{
        text-align: left;
        {padding_px}
    }}



    table.lb_table tr:hover {{
        background-color: {str_background_bover} !important;
    }}

    table.lb_table tr:nth-child(even) {{
        background-color: {str_row_even};
    }}
    table.lb_table tr:nth-child(odd) {{
        background-color: {str_row_odd};
    }}



    table.lb_table button {{
        background-color: {str_background_color};
        color: {str_text_color};
        border: none;
        border-radius: 8px;
        padding: 4px 10px;
        cursor: pointer;
        font-weight: bold;
    }}
    table.lb_table button:hover {{
        background-color: {str_background_color};
        color: {str_text_color};
    }}

    .lb_link {{
        color: {str_text_color};
        text-decoration: none;
    }}
    .lb_link:hover {{
        color: {str_text_blue};
    }}

    table.lb_table img {{
        user-select: none;
        pointer-events: none;
        -webkit-user-drag: none;
        draggable: false;
    }}

    select {{
        border-radius: 8px;
        border: 1px solid {str_boder_color};
        padding: 2px 2px;
        background-color: {str_background_color};
        color: {str_text_color};
        outline: none;
        margin-bottom: 4px;
        margin-right: 4px;
        transition: border-color 0.2s;
        box-shadow: 0px 1px 2px rgba(20,20,20,0.07);
        cursor: pointer;

    }}

    select:hover {{
        border-color: {str_text_blue};
    }}


    table.lb_table tr td:first-child,
    table.lb_table tr th:first-child {{
        border-top-left-radius: {str_border_radius}px;
        border-bottom-left-radius: {str_border_radius}px;
    }}
    table.lb_table tr td:last-child,
    table.lb_table tr th:last-child {{
        border-top-right-radius: {str_border_radius}px;
        border-bottom-right-radius: {str_border_radius}px;
    }}


    .lb_button {{
        display: inline-block;
        border-radius: 8px;
        background-color: {str_background_color};
        color: {str_text_color};
        padding: 2px 5px;
        border: 1px solid {str_boder_color};
        cursor: pointer;
        text-align: center;
    }}
    .lb_button:hover {{
        background-color: {str_background_bover};
        border-color: {str_text_blue};
    }}


    .lb_box_text {{
        display: inline-block;
        border-radius: 4px;
        background-color: {str_background_color};
        color: {str_text_color};
        padding: 1px 4px;
        text-align: center;
        margin: 2px 2px;
        box-shadow: 0px 1px 2px rgba(20,20,20,0.07);
    }}

    /* https://www.w3schools.com/css/css_dropdowns.asp */

    @keyframes popup-fade-in {{
        from {{ opacity: 0; transform: translateY(-6px); }}
        to {{ opacity: 1; transform: translateY(0); }}
    }}

    .dropdown {{
        position: relative;
    }}

    .dropdown-button {{
        background-color:{str_background_color};
        color: {str_text_color};
        padding: 2px 10px;
        font-size: 15px;
        cursor: pointer;
        border-radius: 8px;
        border: 1px solid {str_boder_color};
        padding-right: 20px;
        position: relative;
    }}

    .dropdown-button::after {{
        content: "";
        position: absolute;
        right: 6px;
        top: 50%;
        transform: translateY(-50%);
        width: 12px;
        height: 12px;
        background-image: url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="{str_svg_color}" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg>');
        background-repeat: no-repeat;
        background-size: contain;
    }}


    .dropdown-title {{
        color: #bdbdbd;
        padding: 2px 10px;
        font-size: 13px;
        font-weight: bold;
        user-select: none;
        pointer-events: none;
        cursor: default;
    }}

    .dropdown-content {{
        border-radius: 8px;
        border: 1px solid {str_boder_color};
        font-size: 13px;
        display: none;
        position: absolute;
        background-color: {str_background_color_02};
        min-width: 50px;
        box-shadow: 0px 1px 2px rgba(20,20,20,0.07);
        left: 0;
        top: 110%;
        z-index: 10;
        animation: popup-fade-in 0.18s ease;
        text-align: center;
        white-space: nowrap;
        max-height: 300px;
        overflow-y: auto;
    }}

    .dropdown:focus-within .dropdown-content,
    .dropdown:active .dropdown-content {{
        display: block;
    }}

    .dropdown-content a {{
        color: {str_text_color};
        padding: 1px 10px;
        text-decoration: none;
        display: block;
        cursor: pointer;
    }}

    .dropdown-content a:hover {{
        background-color: {str_text_blue};
        color: black;
        border-radius: 8px;
    }}

    .dropdown:hover .dropdown-button {{
        border: 1px solid {str_text_blue};
    }}


    .lb_tooltip[data-tooltip] {{
        position: relative;
    }}

    .lb_tooltip[data-tooltip]:hover::after {{
        content: attr(data-tooltip);
        position: absolute;
        left: 50%;
        bottom: 125%;
        transform: translateX(-50%);
        background-color: {str_background_color};
        color: {str_text_color};
        padding: 4px 8px;
        border-radius: 4px;
        font-size: 15px;
        z-index: 1002;
        display: block;
        white-space: nowrap;
        pointer-events: none;
        box-shadow: 0px 2px 4px rgba(0,0,0,0.2);
    }}


</style>
"""

    from .colors_config import get_color_config
    colors = get_color_config()

    result = []

    lb_length = len(lb)

    if is_legacy_mode:
        config_maxUsers = config["maxUsers"]
    else:
        config_maxUsers = max_users_v2
        if config_maxUsers > 100:
            config_maxUsers = 100

    if config_maxUsers > lb_length:
        config_maxUsers = lb_length

    def check_user_index(item):
        _user_index = None

        if manually_user_index:
            _user_index = manually_user_index

        elif config["username"] == item[1].split(" |")[0]:
            _user_index = lb.index(item)

        return _user_index

    user_index = 1

    if config["focus_on_user"] == True and len(lb) > config_maxUsers:
        for item in lb:

            _user_index = check_user_index(item)
            if _user_index:
                user_index = _user_index

                half_max_users = config_maxUsers // 2
                extra = 0
                if config_maxUsers % 2 != 0:
                    extra = 1

                # username ﾘｽﾄ末尾
                if user_index + half_max_users + extra > lb_length:
                    rank_start = max(0, lb_length - config_maxUsers) + 1
                    rank_end = user_index + 1

                    for item in range(rank_start, rank_end):
                        if 0 <= item < lb_length:
                            result.append(lb[item])
                    break

                # username ﾘｽﾄ上半分
                # ﾕｰｻﾞｰが半分上にいる
                if user_index - half_max_users < 0:
                    # rank_start = user_index
                    # rank_end = user_index + config["maxUsers"]
                    rank_start = 0
                    rank_end = config_maxUsers

                    for item in range(rank_start, rank_end):
                        if 0 <= item < lb_length:
                            result.append(lb[item])
                    break


                else:
                    # username 中央
                    rank_start = user_index - half_max_users
                    rank_end = user_index + half_max_users + extra

                    for item in range(rank_start, rank_end):
                        if 0 <= item < lb_length:
                            result.append(lb[item])
                    break


        if not result:
            result = lb[:config_maxUsers]


    else:

        result = lb[:config_maxUsers]

        gold_color = colors["GOLD_COLOR"]
        silver_color = colors["SILVER_COLOR"]
        bronze_color = colors["BRONZE_COLOR"]

        gold_color = hex_color_to_rgba(gold_color, COLOR_ALPHA)
        silver_color = hex_color_to_rgba(silver_color, COLOR_ALPHA)
        bronze_color = hex_color_to_rgba(bronze_color, COLOR_ALPHA)

        table_style += f"""
<style>
table.lb_table tr:nth-child(2) {{
    background-color: {gold_color};
}}

table.lb_table tr:nth-child(3) {{
    background-color: {silver_color};
}}

table.lb_table tr:nth-child(4) {{
    background-color: {bronze_color};
}}
</style>
"""

    # save page
    cache_board_data["user_index"] = user_index, config_maxUsers, lb_length


    #MARK:t-global
    if config["tab"] != 4:

        str_country_header = ""
        str_rank_header = "#"
        str_font_percentage= ""
        if not is_legacy_mode:
            str_country_header = '<th style="text-align:center">Country</th>'
            str_rank_header = "Rank"
            str_font_percentage= ";font-size:80%;"



        table_header = f"""
<table class="lb_table" part="shige_lb_table">
    <tr>
        <th style="text-align:center">{str_rank_header}</th>
        <th style="text-align:center">Username</th>
        <th style="text-align:center">Reviews</th>
        <th style="text-align:center">Minutes</th>
        <th style="text-align:center">Streak</th>
        <th style="text-align:center">31days</th>
        <th style="text-align:center{str_font_percentage}">Retention</th>
        {str_country_header}
    </tr>
"""
        table_content = ""

        for item in result:

            if not is_legacy_mode:
                item = make_global_display_text(item)

            counter = item[0]
            username = item[1] # type:str
            cards = item[2]
            time = item[3]
            streak = item[4]
            month = item[5]
            retention = item[6]
            country = item[7] # type:str

            username_split = username.split(" |")[0]

            if username_split == config["username"]:
                color = colors["USER_COLOR"]
            elif username_split in config["friends"] and not config["tab"] == 1:
                color = colors["FRIEND_COLOR"]
            else:
                color = ""

            if color:
                color = hex_color_to_rgba(color, COLOR_ALPHA)

            # country
            str_country_html = ""
            if not is_legacy_mode:
                str_country_html = f'<td style="text-align:left">{country}</td>'


            display_username = username
            if not is_legacy_mode and " |" in username:
                display_username = username.replace(" |", "<br>")


            str_username_html = f"<b>{display_username}</b>"


            # icon
            str_icon_html = ""
            if not is_legacy_mode and home_icon_downloader and add_pic_country_and_league:
                int_icon_size = USER_ICON_SIZE
                result = home_icon_downloader.get_by_username(username_split, int_icon_size)
                path_exists, image_data, new_text = result
                if path_exists:
                    add_space = " "
                    str_icon_html = f"{add_align_middle(new_text)}{add_space}"

                    try:
                        str_username_html = make_multiple_box(str_icon_html, str_username_html)
                    except Exception as e:
                        print(f"[{ADDON_NAME}] Error: {e} ")

            # blur
            if hide_other_users and not username_split == config["username"]:
                str_username_html = f'<b style="filter: blur(4px);"">{str_username_html}</b>'


            str_text_pos= "right"
            if not is_legacy_mode:
                str_text_pos = "left"

            if retention:
                str_percent = "%"
            else:
                str_percent = ""


            table_content = table_content + f"""
<tr style="background-color:{color}">
    <td style="text-align:{str_text_pos}">{counter}</td>
    <td>
    <button
        style="
            outline:0 !important;
            cursor:pointer;
            border: none;
            background: none;
            "
        type="button"
        onclick="pycmd('userinfo:{username}')">
        {str_username_html}
        </button>
    </td>
    <td style="text-align:{str_text_pos}">{cards}</td>
    <td style="text-align:{str_text_pos}">{time}</td>
    <td style="text-align:{str_text_pos}">{streak}</td>
    <td style="text-align:{str_text_pos}">{month}</td>
    <td style="text-align:{str_text_pos}">{retention}{str_percent}</td>
    {str_country_html}
</tr>
"""

    from .lb_home_v2.calculate_display_text import get_country_sub

    #MARK:t-league
    if config["tab"] == 4:


        str_html_country_column = ""
        str_rank_header = "#"
        if not is_legacy_mode:
            str_html_country_column = """<th style="text-align:center">Country</th>"""
            str_rank_header = "Rank"


        if not is_legacy_mode:
            mini_font_size = "; font-size:90%;"
        else:
            mini_font_size = ""


        table_header = f"""
<table class="lb_table" part="shige_lb_table">
    <tr>
        <th>{str_rank_header}</th>
        <th>Username</th>
        <th style="text-align:center">XP</th>
        <th style="text-align:center">Minutes</th>
        <th style="text-align:center">Reviews</th>
        <th style="text-align:center{mini_font_size}">Retention</th>
        <th style="text-align:center{mini_font_size}">Days learned</th>
        {str_html_country_column}
    </tr>
"""
        table_content = ""

        for item in result:

            if not is_legacy_mode:
                item = make_league_display_text(item)

            # counter, username, xp, time_spend, reviews, retention, days_learned
            counter = item[0]
            username = item[1]
            xp = item[2]
            time_spend = item[3]
            reviews = item[4]
            retention = item[5]
            days_learned = item[6]

            username_split = username.split(" |")[0]

            if username_split == config["username"]:
                color = colors["USER_COLOR"]
            elif username_split in config["friends"]:
                color = colors["FRIEND_COLOR"]
            else:
                color = ""

            if color:
                color = hex_color_to_rgba(color, COLOR_ALPHA)


            display_username = username
            if not is_legacy_mode and " |" in username:
                display_username = username.replace(" |", "<br>")

            # icon
            str_username_html = f"<b>{display_username}</b>"

            # icon
            str_icon_html = ""
            if not is_legacy_mode and home_icon_downloader and add_pic_country_and_league:
                int_icon_size = USER_ICON_SIZE
                result = home_icon_downloader.get_by_username(username_split, int_icon_size)
                path_exists, image_data, new_text = result
                if path_exists:
                    add_space = " "
                    str_icon_html = f"{add_align_middle(new_text)}{add_space}"

                    try:
                        str_username_html = make_multiple_box(str_icon_html, str_username_html)
                    except Exception as e:
                        print(f"[{ADDON_NAME}] Error: {e} ")

            # blur
            if hide_other_users and not username_split == config["username"]:
                str_username_html = f'<b style="filter: blur(4px);"">{str_username_html}</b>'


            if retention:
                str_percent = "%"
            else:
                str_percent = ""

            if days_learned:
                str_percent_days = "%"
            else:
                str_percent_days = ""

            str_text_pos= "right"
            if not is_legacy_mode:
                str_text_pos = "left"

            str_country_html = ""
            if not is_legacy_mode:
                try:
                    _country_html = get_country_sub(username_split)
                    str_country_html = (
                        f'<td style="text-align:{str_text_pos}">'
                        f'{_country_html}'
                        f'</td>'
                        )
                except Exception as e:
                    print(f"[{ADDON_NAME}] {e}")


            table_content = table_content + f"""
<tr style="background-color:{color}">
    <td style="text-align:{str_text_pos}">{counter}</td>
    <td>
        <button
        style="
            outline:0 !important;
            cursor:pointer;
            border: none;
            background: none;"
        type="button"
        onclick="pycmd('userinfo:{username}')">
        <b>{str_username_html}</b>
        </button>
    </td>
    <td style="text-align:{str_text_pos}">{xp}</td>
    <td style="text-align:{str_text_pos}">{time_spend}</td>
    <td style="text-align:{str_text_pos}">{reviews}</td>
    <td style="text-align:{str_text_pos}">{retention}{str_percent}</td>
    <td style="text-align:{str_text_pos}">{days_learned}{str_percent_days}</td>
    {str_country_html}
</tr>
"""


    shige_text = f"""<br>"""

    if config.get("show_home_buttons", True):

        rate_and_donation = ""
        if config.get("rate_and_donation_buttons", True):
            # rate_and_donation = (
            # '<a class="lb_link" href="https://ankiweb.net/shared/review/175794613">👍️Rate</a> |'
            # # '<a class="lb_link" href="http://patreon.com/Shigeyuki">💖Donate</a> |'
            # '<a class="lb_link" href="http://patreon.com/Shigeyuki">💖Donate</a>'
            # )
            rate_and_donation = (
            '<a class="lb_link lb_rate_link lb_tooltip" href="https://ankiweb.net/shared/review/175794613" data-tooltip="If you like this add-on please recommend it!">👍️Rate</a> |'
            '<a class="lb_link lb_donate_link lb_tooltip" href="http://patreon.com/Shigeyuki" data-tooltip="Become a patron to get Leaderboard-Plus!">💖Donate</a>'
            )

        current_sort = config.get("sortby", "Cards")

        STR_SELECTED = " selected"
        now_sort_name = "Review"

        if current_sort == "Cards": #"Reviews"
            now_sort_name = "Review"
        elif current_sort == "Time_Spend": # "Time"
            now_sort_name = "Time"
        elif current_sort == "Streak":
            now_sort_name = "Streak"
        elif current_sort == "Month": # "31days"
            now_sort_name = "31days"
        elif current_sort == "Retention":
            now_sort_name = "Retention"

        # tab
        current_tab = config.get("tab", 0)
        now_tab_name = "Global"
        if current_tab == 0:
            now_tab_name = "Global"
        elif current_tab == 1:
            now_tab_name = "Friends"
        elif current_tab == 2:
            now_tab_name = "Country"
        elif current_tab == 3:
            now_tab_name = "Group"
        elif current_tab == 4:
            now_tab_name = "League"


        # mode
        now_mode_name = "V2s"

        if current_mode == "Legacy":
            now_mode_name = "Legacy"
        elif current_mode == "Game":
            now_mode_name = "V2"
        elif current_mode == "G-Mini":
            now_mode_name = "Mini"



        # start div
        shige_text += f"""
<div>"""

        str_extra_info = ""


        #MARK:V2
        if not is_legacy_mode:

            shige_text += f"""
<div class="dropdown" data-tooltip="Board type" style="display:inline;">
    <button class="dropdown-button">{now_tab_name}</button>
    <div class="dropdown-content">
    <div class="dropdown-title">board</div>
        <a onclick="pycmd('shige_leaderboard_board_select:Global')">Global</a>
        <a onclick="pycmd('shige_leaderboard_board_select:Friends')">Friends</a>
        <a onclick="pycmd('shige_leaderboard_board_select:Country')">Country</a>
        <a onclick="pycmd('shige_leaderboard_board_select:Group')">Group</a>
        <a onclick="pycmd('shige_leaderboard_board_select:League')">League</a>
    </div>
</div>
"""



            # se-sort, not league board
            if not config["tab"] == 4:
                shige_text += f"""
<div class="dropdown" data-tooltip="Sort by" style="display:inline;">
    <button class="dropdown-button">{now_sort_name}</button>
    <div class="dropdown-content">
    <div class="dropdown-title">sort</div>
        <a onclick="pycmd('shige_leaderboard_sort_select:Reviews')">Reviews</a>
        <a onclick="pycmd('shige_leaderboard_sort_select:Time')">Time</a>
        <a onclick="pycmd('shige_leaderboard_sort_select:Streak')">Streak</a>
        <a onclick="pycmd('shige_leaderboard_sort_select:31days')">31days</a>
        <a onclick="pycmd('shige_leaderboard_sort_select:Retention')">Retention</a>
    </div>
</div>"""

            #MARK: group tab
            if config["tab"] == 3:
                group_options = ""

                now_group_name = ""
                if config["current_group"]:
                    current_group = config.get("current_group") #type:str
                    if current_group:
                        now_group_name = html.escape( current_group)


                for idx, user_group_name in enumerate(config.get("groups", [])):
                    user_group_name: str

                    # 一部のｸﾞﾙｰﾌﾟ名には特殊文字が含まれるのでｴｽｹｰﾌﾟ
                    code_group_name = html.escape(user_group_name)

                    # ｸﾞﾙｰﾌﾟ名はpycmdで直接送信しない
                    key_index = idx

                    try:
                        # group_options += f'<option value="{key_index}"{selected}>{code_group_name}</option>\n'
                        group_options += f"""<a onclick="pycmd('shige_leaderboard_select_group:{key_index}')">{code_group_name}</a>\n"""
                    except Exception as e:
                        print(f"[{ADDON_NAME}] Error: {e}")

                if group_options:

                    str_channel_shield = ""
                    try:
                        from .make_shield import make_channel_shield
                        str_channel_shield = make_channel_shield(now_group_name)
                    except Exception as e:
                        print(f"[{ADDON_NAME}] Error: {e} ")

                    str_extra_info += f"""
<div class="dropdown" style="display:inline;">
    <button class="dropdown-button">{now_group_name}</button>
    <div class="dropdown-content">
    <div class="dropdown-title">group</div>
        {group_options}
    </div>
        {str_channel_shield}
</div>"""

                shige_text += (
                    f'<a class="lb_button" style="cursor: pointer;" '
                    f"""onclick="pycmd('shige_leaderboard_search_group')">"""
                    f'Search Group</a>'
                    )


            #MARK:league tab
            if config["tab"] == 4:
                league_options = ""

                home_selected_league = lo_config.get("home_selected_league")
                if home_selected_league:
                    user_league_name = home_selected_league
                else:
                    user_league_name = get_cache_board_data().get("user_league_name", "Delta")

                league_names = ["Alpha", "Beta", "Gamma", "Delta"]

                league_icons = {
                "Delta": "delta_12.png",
                "Gamma": "gamma_12.png",
                "Beta": "beta_12.png",
                "Alpha": "alpha_12.png",
                }

                league_stars = {
                "Delta": "★",
                "Gamma": "★★",
                "Beta": "★★★",
                "Alpha": "★★★★",
                }
                user_stars = league_stars.get(user_league_name, "★")
                now_user_league_display_name = f"{user_league_name} {user_stars}"

                for idx, league_name in enumerate(league_names):
                    key_index = idx

                    # selected = ""
                    # if user_league_name == league_name:
                    #     selected = " selected"

                    stars = league_stars.get(league_name, "★")
                    display_name = f"{league_name} {stars}"


                    try:
                        # league_options += f'<option value="{league_name}"{selected}>{display_name}</option>\n'
                        league_options +=f"""<a onclick="pycmd('shige_leaderboard_select_league:{league_name}')">{display_name}</a>\n"""
                    except Exception as e:
                        print(f"[{ADDON_NAME}] Error: {e}")

                if league_options:

                    icon_html = ""
                    if user_league_name:
                        from .create_icon import create_leaderboard_icon
                        league_icon_filename = league_icons.get(user_league_name, "delta_12.png")
                        league_icon_path = create_leaderboard_icon(
                            file_name=league_icon_filename,
                            icon_type="shield",
                            is_need_only_path=True)

                        from .lb_home_v2.calculate_display_text import make_icon_html
                        icon_html = make_icon_html(league_icon_path, 18)
                        icon_html = add_align_middle(icon_html)

                    shige_text += f"""
<div class="dropdown" style="display:inline;">
    <button class="dropdown-button">{icon_html} {now_user_league_display_name}</button>
    <div class="dropdown-content">
    <div class="dropdown-title">league</div>
        {league_options}
    </div>
</div>"""


                from . import get_startup_shige_leaderboard
                startup = get_startup_shige_leaderboard()
                startup.start
                if startup.currentSeason:
                    time_remaining = startup.end - datetime.datetime.now()
                    tr_days = time_remaining.days
                    if tr_days < 0:
                        if is_mini_mode:
                            diplay_text = "Season End"
                        else:
                            diplay_text = f"The current season is over, the new season will start next Monday."
                    else:
                        if is_mini_mode:
                            diplay_text = f"{tr_days} left"
                        else:
                            diplay_text = f"{tr_days} days remaining"

                    str_channel_shield = ""
                    try:
                        from .make_shield import make_channel_shield
                        str_channel_shield = make_channel_shield(user_league_name)
                    except Exception as e:
                        print(f"[{ADDON_NAME}] Error: {e} ")


                    str_extra_info = (
                        f'<span class="lb_box_text">[ {startup.currentSeason} ] '
                        f'{diplay_text}'
                        f'</span>'
                        f'{str_channel_shield}'

                        )




            #MARK: friend tab
            if config["tab"] == 1:
                shige_text += (
                    f'<a class="lb_button" style="cursor: pointer;" '
                    f"""onclick="pycmd('shige_leaderboard_search_friends')">"""
                    f'Search User</a>'
                    )


            #MARK: country tab
            if config["tab"] == 2:

                from .lb_home_v2.calculate_country import calculate_country
                country_html = calculate_country()
                if country_html:
                    str_extra_info = country_html


                shige_text += (
                    f'<a class="lb_button" style="cursor: pointer;" '
                    f"""onclick="pycmd('shige_leaderboard_search_country')">"""
                    f'Join Country</a>'
                    )



        #MARK:legasy+V2

        # se-mode
        shige_text += f"""
<div class="dropdown" data-tooltip="Version" style="display:inline;">
    <button class="dropdown-button">{now_mode_name}</button>
    <div class="dropdown-content">
    <div class="dropdown-title">mode</div>
        <a onclick="pycmd('shige_leaderboard_mode_select:Legacy')">Legacy</a>
        <a onclick="pycmd('shige_leaderboard_mode_select:Game')">V2</a>
    </div>
</div>"""


        #MARK: url

        if not is_legacy_mode:
            sync_tooltip_css = ""
            try:
                from .lb_home_v2.now_loading_checker import sync_info_tooltip_style
                sync_tooltip_css = sync_info_tooltip_style(str_text_color, str_background_color)
            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e} ")

            str_sync_button_html = f"""\
    <span style="position: relative; display: inline-block;">
        <a class="lb_link"
            style="cursor: pointer;"
            onclick="pycmd('shige_leaderboard_sync_and_update')"
            id="shige_sync_text"
            onmouseover="pycmd('shige_leaderboard_sync_info_tooltip:show')"
            onmouseout="pycmd('shige_leaderboard_sync_info_tooltip:hide')"
            >🌐Sync</a>
            <span id="shige_sync_tooltip" class="shige_sync_tooltip"></span>
            <span id="{ID_SHIGE_SYNC_LOADING_ICON}" style="vertical-align: middle;"></span> |
    {sync_tooltip_css}
    </span>"""

        else:
            str_sync_button_html = f"""\
    <a class="lb_link" style="cursor: pointer;" onclick="pycmd('shige_leaderboard_sync_and_update')">🌐Sync</a>
        <span id="{ID_SHIGE_SYNC_LOADING_ICON}" style="vertical-align: middle;"></span> |"""


        shige_text += f"""
    <span class="lb_box_text">

    <a class="lb_link" data-tooltip="Open the window version leaderboard" style="cursor: pointer;" onclick="pycmd('shige_leaderboard')">🏆️Board</a> |
    {str_sync_button_html}
    <a class="lb_link" data-tooltip="Open the Config window" style="cursor: pointer;" onclick="pycmd('shige_leaderboard_config')">⚙️Conf</a> |
    <a class="lb_link" data-tooltip="Open the How to Wiki" href="https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html">📖Wiki</a> |
    {rate_and_donation}
    </span>
    <div style="text-align: center;">{str_extra_info}</div>
    """

        # end div
        shige_text += f"""
</div>"""


    #MARK: end table
    end_table = f"""</table>"""


    bottom_items_html = ""

    if not is_legacy_mode and config.get("show_home_buttons", True):
        bottom_items_html += """\
<div>
"""

        try:
            if config["tab"] == 4:
                int_total_user = cache_board_data.get("league_total_user", 0)
            else:
                int_total_user = cache_board_data.get("board_total_user", 0)

            is_no_page = int_total_user <= max_users_v2

        except Exception as e:
            print(f"[{ADDON_NAME}] Error:{e} ")
            is_no_page = True


        if not is_no_page:
            #MARK:page skip

            if int_total_user <= 100:
                skip_threshold = 10
            else:
                skip_threshold = 100


            page_skip_number_list = []

            if int_total_user:
                for skip_item in range(0, int_total_user):
                    if skip_item % skip_threshold == 0:
                        skip_item = min(max(skip_item + 1, 1), int_total_user)
                        page_skip_number_list.append(skip_item)

            select_page_skip_options = ""
            now_page_number = "1"
            for n2_item in page_skip_number_list:

                if user_index >= n2_item and user_index <= (n2_item + skip_threshold):
                    now_page_number = n2_item

                select_page_skip_options += (
                    f"""<a onclick="pycmd('shige_leaderboard_page_skip:{n2_item}')">{n2_item}</a>"""
                    )

            page_skip_html = ""
            if select_page_skip_options:

                page_skip_html = f"""\
<div class="dropdown" style="display:inline;">
    <button class="dropdown-button">{now_page_number}</button>
    <div class="dropdown-content" style="text-align:left; bottom: 110%; top: auto;">
    <div class="dropdown-title">page</div>
        {select_page_skip_options}
    </div>
</div>
"""

            bottom_items_html += page_skip_html


        if not is_no_page:
            page_buttons_html = """\
    <span class="lb_box_text">
        <a class="lb_link"
            style="cursor: pointer; vertical-align: middle;"
            onclick="pycmd('shige_leaderboard_page:top')"> top </a></span>

    <span class="lb_box_text">
        <a class="lb_link" style="cursor: pointer;" onclick="pycmd('shige_leaderboard_page:before')">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" style="vertical-align: middle;">
                <polygon points="17,4 7,12 17,20" />
            </svg>
        </a></span>

    <span class="lb_box_text">
        <a class="lb_link" style="cursor: pointer;" onclick="pycmd('shige_leaderboard_page:center')">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" style="vertical-align: middle;">
                <circle cx="12" cy="12" r="7" />
            </svg>
        </a></span>

    <span class="lb_box_text">
        <a class="lb_link" style="cursor: pointer;" onclick="pycmd('shige_leaderboard_page:next')">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" style="vertical-align: middle;">
                <polygon points="7,4 17,12 7,20" />
            </svg>
        </a></span>
"""
            bottom_items_html += page_buttons_html



        #MARK:max row box
        number_select_options = ""
        number_list = [
            0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
            15, 20, 25, 30, 40, 50, 60, 70, 80, 90, 100
        ]

        now_row_number = "10"
        for n_item in number_list:

            if max_users_v2 == n_item:
                now_row_number = n_item
            number_select_options += (
                # f'<option value="{n_item}"{str_number_style}{selected}>{n_item}</option>'
                f"""<a onclick="pycmd('shige_leaderboard_select_max_row:{n_item}')">{n_item}</a>"""
                )

        max_show_user_html = f"""\
<div class="dropdown" style="display:inline;">
    <button class="dropdown-button">{now_row_number}</button>
    <div class="dropdown-content" style="text-align:left; bottom: 110%; top: auto;">
    <div class="dropdown-title">row</div>
        {number_select_options}
    </div>
</div>
"""
        bottom_items_html += max_show_user_html




        #MARK: show home
        bottom_items_html += make_show_home_checkbox()



        #MARK: autosync
        is_autosync = config.get("autosync", True)

        toggle_sync_button_html = make_checkbox_normal(
            text="auto-sync",
            element_id="shige_leaderboard_toggle_autosync",
            pycmd_key="shige_leaderboard_toggle_autosync",
            is_checked=is_autosync,
        )

        bottom_items_html += toggle_sync_button_html



        #MARK: yesterday
        if config["tab"] != 4: # not league
            is_start_yesterday = config.get("start_yesterday", True)

            toggle_yesterday_button_html = make_checkbox_normal(
                text="2days",
                element_id="shige_leaderboard_start_yesterday_checkbox",
                pycmd_key="shige_leaderboard_start_yesterday_checkbox",
                is_checked=is_start_yesterday,
            )

            bottom_items_html += toggle_yesterday_button_html


        #MARK:buttons
        is_show_home_buttons = config.get("show_home_buttons", True)
        toggle_show_home_buttons_html = make_checkbox_normal(
            text="buttons",
            element_id="shige_leaderboard_show_buttons_checkbox",
            pycmd_key="shige_leaderboard_show_buttons_checkbox",
            is_checked=is_show_home_buttons,
        )

        bottom_items_html += toggle_show_home_buttons_html


        #MARK:shields


        #MARK:buttons
        is_show_discord_button = config.get("discord_button", True)
        toggle_discord_button_html = make_checkbox_normal(
            text="discord",
            element_id="shige_leaderboard_discord_button_checkbox",
            pycmd_key="shige_leaderboard_discord_button_checkbox",
            is_checked=is_show_discord_button,
        )

        bottom_items_html += toggle_discord_button_html


        try:
            from .make_shield import make_shields_io_html
            str_shield_html = make_shields_io_html()
            if str_shield_html:
                str_br = "<br>"
                bottom_items_html += f"{str_br}{str_shield_html}"
        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {e}")

        #MARK: bottm end
        bottom_items_html += """\
</div>
"""


    #MARK:legacy home btn

    if not config.get("show_home_buttons", True):
        toggle_buttons_html = make_show_buttons_checkbox()
        if toggle_buttons_html:
            bottom_items_html += (
                        f'<div>'
                        f'{toggle_buttons_html}'
                        f'</div>'
                        )



    result_html = f"""{table_style}{shige_text}{table_header}{table_content}{end_table}{bottom_items_html}"""

    return result_html



#MARK:hook


def leaderboar_save_data(response):
    global data
    data = response

    try:
        from .lb_home_v2.now_loading_checker import save_last_sync_time
        save_last_sync_time()
    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e} ")


# def leaderboar_save_data(response):
#     global data
#     data = response


def leaderboar_offline_mode():
    global data
    import os

    addon_path = os.path.dirname(__file__)
    json_path = os.path.join(addon_path, "user_files", "_leaderboard_response_test_data.json")

    if not os.path.exists(json_path):
        print(f"[{ADDON_NAME}] file not found {json_path}")
        data = None
        return
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)


def leaderboard_on_deck_browser(response):
    # global data
    # data = response

    # debug only -------------
    lo_config = get_local_config()
    config = mw.addonManager.getConfig(__name__)
    if lo_config.get("_debug_use_local_data") and config.get("tab") == 4:
        leaderboar_offline_mode()
    # ------------------------

    else:
        # nomal
        leaderboar_save_data(response)


    if mw.state == "deckBrowser":
        refresh_home_board()



#MARK:userinfo

def deckbrowser_linkHandler_wrapper(overview, url):
    url = url.split(":")
    if url[0] == "userinfo":
        mw.shige_user_info = start_user_info(url[1], False)
        mw.shige_user_info.show()
        mw.shige_user_info.raise_()
        mw.shige_user_info.activateWindow()

DeckBrowser._linkHandler = wrap(DeckBrowser._linkHandler, deckbrowser_linkHandler_wrapper, "after")



#MARK:show home
def make_show_home_checkbox(text="show-home", mini_mode=False):
    try:
        config = mw.addonManager.getConfig(__name__)
        is_show_home_screen = config.get("homescreen", True)

        if mini_mode:
            toggle_buttons_html = make_checkbox_mini(
                text=text,
                element_id="shige_leaderboard_show_home_checkbox",
                pycmd_key="shige_leaderboard_show_home_checkbox",
                is_checked=is_show_home_screen,
            )
            return toggle_buttons_html

        else:
            toggle_buttons_html = make_checkbox_normal(
                text=text,
                element_id="shige_leaderboard_show_home_checkbox",
                pycmd_key="shige_leaderboard_show_home_checkbox",
                is_checked=is_show_home_screen,
            )

            return toggle_buttons_html

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")
        return ""





#MARK:show buttons
def make_show_buttons_checkbox(text="show-buttons"):
    try:
        config = mw.addonManager.getConfig(__name__)
        is_show_home_buttons = config.get("show_home_buttons", True)

        return make_checkbox_mini(
            text=text,
            element_id="shige_leaderboard_show_buttons_checkbox",
            pycmd_key="shige_leaderboard_show_buttons_checkbox",
            is_checked=is_show_home_buttons,
        )

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")
        return ""



#📍use from other .py file
def refresh_home_board():
    if mw.state == "deckBrowser":
        on_query_op_home_board()


#MARK:tom select
def on_refresh_home_board(result_html):
    print(f"[{ADDON_NAME}] refresh")

    js_code = f"""
(function() {{
    var container = document.getElementById('{SHIGE_LB_CONTAINER}');
    if (container) {{
        container.innerHTML = "";
        var shadow = container.shadowRoot || container.attachShadow({{mode: 'open'}});
        shadow.innerHTML = `{result_html}`;
    }} else {{
        pycmd('shige_leaderboard_need_deckBrowser_refresh');
    }}
}})();
"""
    mw.deckBrowser.web.eval(js_code)

