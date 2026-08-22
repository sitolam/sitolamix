# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import math
import datetime

from .lb_home_tools import make_icon_html, add_align_middle

from ..create_icon import create_leaderboard_icon
from ..path_manager import ADDON_NAME

from ..custom_shige.path_manager import (
    TIME_FLAT_ICON_LIGHT, TIME_FLAT_ICON_DARK, WEATHER_ICON, WEATHER_ICON_DARK, TREE_ICON,
    LIFEBAR_ICON, ORB_ICON, XPBAR_ICON
    )

from .lb_home_tools import make_multiple_box

IS_ARART_BY_REVIEW_SECONDS = True
ARART_THRESHOLD = 2

ICON_SIZE = 25
COUNTRY_ICON_SIZE = 20


#MARK: global
def make_global_display_text(item):
    try:
        counter = item[0]
        username = item[1] # type:str
        username_split = username.split(" |")[0]

        cards = item[2]
        time = item[3]
        streak = item[4]
        month = item[5]
        retention = item[6]
        country = item[7] # type:str


        # cards
        if counter:
            item[0] = get_gloabl_rank_sub(username_split, counter)
        else:
            counter[0] = ""


        # cards
        if cards:
            item[2] = get_review_text(cards, time, month)
        else:
            item[2] = ""


        # time
        if time:
            item[3] = get_time_text(time)
        else:
            item[3] = ""


        # streak
        if streak:
            item[4] = get_streak_text(streak)
        else:
            item[4] = ""


        # month
        if month:
            item[5] = get_31days_text(month)
        else:
            item[5] = ""


        # retenion
        if retention:
            # item[6] = f"{int(retention)}"
            item[6] = get_retention(retention)
        else:
            item[6] = ""


        # country
        if country:
            item[7] = get_country_icon(country)
        else:
            item[7] = ""



    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e} ")

    return item

def get_league_days():
    from .. import get_startup_shige_leaderboard
    startup = get_startup_shige_leaderboard()
    if startup.start == startup.end:
        league_days = 14
    else:
        league_days = max(0, min(14, ((datetime.datetime.now() - startup.start).days) +1 ))
    return league_days


#MARK: League
def make_league_display_text(item):
    try:

        # counter, username, xp, time_spend, reviews, retention, days_learned
        counter = item[0]
        username = item[1]

        xp = item[2]
        time_spend = item[3]
        reviews = item[4]
        retention = item[5]
        days_learned = item[6]

        league_days = get_league_days()


        if counter:
            item[0] = make_rank_text(counter)

        if xp:
            item[2] = get_xp_and_level_text(xp)
        else:
            item[2] = ""

        if time_spend:
            item[3] = get_league_time(time_spend, league_days)
        else:
            item[3] = ""


        if reviews:
            item[4] = get_league_review(reviews, time_spend, league_days)
        else:
            item[4] = ""

        if retention:
            # item[5] = f"{int(retention)}"
            item[5] = get_retention(retention)
        else:
            item[5] = ""

        if days_learned:
            # item[6] = f"{int(days_learned)}"
            item[6] = get_retention(days_learned)
        else:
            item[6] = ""


    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e} ")

    return item





#MARK:get country sub
def get_user_data_sub(username):
    country = ""
    league_name = ""
    sync_today = ""

    from ..lb_on_homescreen import get_cache_user_data_sub
    result = get_cache_user_data_sub().get(username)
    if result and isinstance(result, list):
        if len(result) > 0 and result[0]:
            league_name = result[0]
        if len(result) > 1 and result[1]:
            country = result[1]
        if len(result) > 2 and result[2]:
            sync_today = result[2]

    return league_name, country, sync_today

# country sub
def get_country_sub(username):
    league_name, country, sync_today = get_user_data_sub(username)
    if country:
        str_country_html = get_country_icon(country)
        return str_country_html
    return country


#MARK:gloabl rank sub
def get_gloabl_rank_sub(username, counter):
    league_name, country, sync_today = get_user_data_sub(username)

    # if league_name:
    #     str_le_review_html = get_country_icon(country)
    #     return str_le_review_html

    from ..lb_on_homescreen import get_cache_board_data
    from ..check_user_rank import compute_user_rank
    league_total_user = get_cache_board_data().get("board_total_user")
    result = compute_user_rank(counter, league_total_user)
    # print(f"[{ADDON_NAME}] counter:{counter} total:{league_total_user} result:{result}")
    rank_number, rank_a_f, league_percentage_text = result


    str_span_font_size = ''
    str_span_end = '</span>'

    if counter and isinstance(counter, int):
        if counter >= 100:
            str_span_font_size = '<span style="font-size:90%">'
        elif  counter >= 1000:
            str_span_font_size = '<span style="font-size:80%">'


    if ("-" in rank_a_f) or ("+" in rank_a_f):
        display_text = f"{rank_a_f} {str_span_font_size}{counter}{str_span_end}"
    else:
        display_text = f"{rank_a_f}&nbsp;&nbsp;&nbsp;{str_span_font_size}{counter}{str_span_end}"

    try:
        rank_icon_html = make_rank_icon(rank_number, user_league_name=league_name)

        try:
            dot_icon_html = make_online_dot(username)
            icon_html = f"{dot_icon_html}{rank_icon_html}"
        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {e}")
            icon_html = rank_icon_html

        icon_html = add_align_middle(icon_html)

        str_rank_html = f"{icon_html} {display_text}"

        # str_rank_html = add_rank_warning(rank_number, league_name, icon_html=str_rank_html)



        return str_rank_html

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

    return display_text


#MARK:onlineDot
def make_online_dot(username):
    from ..custom_shige.path_manager import ONLINE_DOT

    league_name, country, sync_today = get_user_data_sub(username)

    icon_path = None

    if sync_today:
        icon_path = ONLINE_DOT[0]
    else:
        icon_path = ONLINE_DOT[1]

    size = ICON_SIZE
    icon_html = make_icon_html(icon_path, size, no_width=True)

    return icon_html



#MARK:rank

def make_rank_icon(rank_number, user_league_name):
    league_name = user_league_name
    size = ICON_SIZE

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
    new_number = ranks_file_number[rank_number]

    league_icon_filename = league_icons.get(league_name, "delta_04.png").replace("_04", f"_{new_number:02}")

    league_icon_path = create_leaderboard_icon(file_name=league_icon_filename,
                                        icon_type="shield",
                                        is_need_only_path=True
                                        )
    icon_html = make_icon_html(league_icon_path, size)

    return icon_html


def add_rank_warning(rank_number, user_league_name, icon_html):
    try:
        from ..colors_config import get_color_config
        colors = get_color_config()

        rank_color = None

        if rank_number in [10, 20] and not user_league_name == "Alpha":
            rank_color = colors.get("LEAGUE_TOP")

        elif rank_number in [90, 100] and not user_league_name == "Delta":
            rank_color = colors.get("LEAGUE_BOTTOM")

        if rank_color:
            icon_html = (
                        f'<span style="background:{rank_color}; '
                        f'border-radius:6px; '
                        f'padding:2px 4px;">'
                        f'{icon_html}'
                        f'</span>'
                        )
    except Exception as e:
        print(f"[{ADDON_NAME}] {e}")

    return icon_html


def make_rank_text(counter):
    try:
        from ..lb_on_homescreen import get_cache_board_data
        from ..check_user_rank import compute_user_rank
        league_total_user = get_cache_board_data().get("league_total_user")
        result = compute_user_rank(counter, league_total_user)
        # print(f"[{ADDON_NAME}] counter:{counter} total:{league_total_user} result:{result}")
        rank_number, rank_a_f, league_percentage_text = result

        str_span_font_size = ''
        str_span_end = '</span>'

        if counter and isinstance(counter, int):
            if counter >= 100:
                str_span_font_size = '<span style="font-size:90%">'
            elif  counter >= 1000:
                str_span_font_size = '<span style="font-size:80%">'

        display_text = f"{rank_a_f} {str_span_font_size}{counter}{str_span_end}"

        try:
            from ..config_local import get_local_config
            lo_config = get_local_config()
            home_selected_league = lo_config.get("home_selected_league")
            if home_selected_league:
                user_league_name = home_selected_league
            else:
                user_league_name = get_cache_board_data().get("user_league_name")
            icon_html = make_rank_icon(rank_number, user_league_name)
            icon_html = add_align_middle(icon_html)

            str_rank_html = f"{icon_html} {display_text}"

            str_rank_html = add_rank_warning(rank_number, user_league_name, icon_html=str_rank_html)

            return str_rank_html

        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {e}")


        return display_text

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")
        return counter




#MARK:icon-reten
# Retention Bonus:
# 85%-100% -> 100%
# 70%-84%  -> 85%
# 55%-69%  -> 70%
# 40%-54%  -> 55%
# 25%-39%  -> 40%
# 10%-24%  -> 25%
# 0%-9%   -> 0%

def get_weather_icon(retention_value):
    retention_value = int(float(retention_value))
    numeric_keys = sorted([int(key) for key in WEATHER_ICON.keys()])
    selected_key = str(numeric_keys[0])
    for key in numeric_keys:
        if key <= retention_value:
            selected_key = str(key)
        else:
            break
    try:
        from aqt.theme import theme_manager
        if theme_manager.night_mode:
            result = WEATHER_ICON_DARK.get(selected_key, None)
        else:
            result = WEATHER_ICON.get(selected_key, None)
    except Exception as e:
        print("Leadearboard Error get_time_icon: ",e)
        result = WEATHER_ICON.get(selected_key, None)
    return result


#MARK: retention
def get_retention(retention):

    display_text = f"{int(retention)}"

    try:
        display_text = f'<span style="font-size:80%">{display_text}</span>'

        size = ICON_SIZE
        icon_path =  get_weather_icon(retention)
        icon_html = make_icon_html(icon_path, size)
        icon_html = add_align_middle(icon_html)
        str_retention_html = f'{icon_html} {display_text}'
        return str_retention_html

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

    return display_text



#MARK: country
def get_country_icon(country:str):
    size = COUNTRY_ICON_SIZE

    from ..custom_shige.country_dict import COUNTRY_FLAGS, COUNTRY_LIST_V2
    flag_icon_file_name = COUNTRY_FLAGS.get(country.replace(" ", ""), "pirate.png")

    str_display_country_name = COUNTRY_LIST_V2.get(country.replace(" ", ""), "Pirate")
    if flag_icon_file_name == "pirate.png":
        str_display_country_name = "Pirate"

    html_country_name = (
                        f'<span style="max-width:70px; '
                            f'display:inline-block; '
                            f'overflow:hidden; '
                            f'text-overflow:ellipsis; '
                            f'white-space:nowrap; '
                            f'font-size:80%; '
                        f'">'
                            f'{str_display_country_name}'
                        f'</span>'
                        )

    country_icon_path = create_leaderboard_icon(
                                        file_name=flag_icon_file_name,
                                        icon_type="flag",
                                        is_need_only_path=True)

    icon_html = make_icon_html(country_icon_path, size)

    # icon_html = f'<img src="{country_icon_path}" width="{size}" height="{size}" >'

    str_country_html = f'{icon_html} {html_country_name}'

    return str_country_html



#MARK:le-review
def get_league_review(reviews, time_spend, league_days):
    is_mini_mode = False

    second = float(time_spend) * 60
    review = int(float(reviews))

    str_span_font_size = '<span style="font-size:80%">'
    str_span_end = '</span>'


    if review == 0:
        display_text = f"{review:,} rev {str_span_font_size}(0sec){str_span_end}"
    else:
        second_per_card = round(max(0, second // review))
        alert_emoji = ""
        if (IS_ARART_BY_REVIEW_SECONDS
            and second_per_card <= ARART_THRESHOLD
            and review > 100):
            alert_emoji = "🚨"
        # display_text = f"{review:,} rev ({alert_emoji}{second_per_card}" + f"sec)"


        cards_14day = review
        if league_days <= 0:
            league_days = 1
        perday = max(0, cards_14day // league_days)

        if is_mini_mode:
            display_text = (f'{int(perday):,}/d'
                            f'{str_span_font_size}'
                            f'({second_per_card}s)'
                            f'{str_span_end}'
                            )
        else:
            display_text = (
                            f'<span style="white-space:nowrap;">'
                            f'{int(perday):,} /d '
                            f'{str_span_font_size}'
                            f'({alert_emoji}'
                            f'{second_per_card}sec)'
                            f'{str_span_end}'
                            f'<br>'
                            f'{str_span_font_size}'
                            f'(tot. {int(cards_14day):,} rev)'
                            f'{str_span_end}'
                            )

    try:
        size = ICON_SIZE
        icon_path =  get_orb_icon(int(perday))
        icon_html = make_icon_html(icon_path, size)

        icon_html = add_align_middle(icon_html)
        # str_le_review_html = f'{icon_html} {display_text}'

        str_le_review_html = make_multiple_box(icon_html, display_text)

        return str_le_review_html

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")


    return display_text





#MARK:le-time
def get_league_time(time_spend, league_days):

    minutes = int(float(time_spend))
    hours = minutes // 60
    remaining_minutes = minutes % 60

    str_span_font_size = '<span style="font-size:80%">'
    str_span_end = '</span>'


    if not league_days == None:
        if league_days <= 0:
            league_days = 1
        else:
            league_days = league_days

        league_minutes = int(max(0, minutes // league_days))
        league_hours = int(max(0, league_minutes // 60))
        league_miniutes = int(max(0, league_minutes % 60))

        display_text = (f'{league_hours:02}h {league_miniutes:02}m /d'
                        f'<br>'
                        f'{str_span_font_size}'
                        f'(tot. {hours:02}h {remaining_minutes:02}m)'
                        f'{str_span_end}'
                        )

        try:
            icon_html = get_time_icon(time_value=league_minutes)
            icon_html = add_align_middle(icon_html)
            # str_time_html = f'{icon_html} {display_text}'

            str_time_html = make_multiple_box(icon_html, display_text)

            return str_time_html

        except Exception as e:
            print(f"[{ADDON_NAME}] Error {e} ")

        return display_text

    return time_spend




#MARK:icon-xp
def get_percentage_to_next_level(exp):
    current_level = math.floor(math.sqrt(exp / 2000))
    current_exp_needed = current_level ** 2 * 2000
    next_level_exp = (current_level + 1) ** 2 * 2000
    exp_needed_for_next = next_level_exp - current_exp_needed
    exp_progress = exp - current_exp_needed
    percent = (exp_progress / exp_needed_for_next) * 100
    return int(percent)

def get_xp_icon(level_value):
    level_value = int(float(level_value))
    key_list = []
    for key in XPBAR_ICON.keys():
        key_list.append(int(key))
    key_list.sort()
    selected_key = str(key_list[0])
    for key in key_list:
        if key <= level_value:
            selected_key = str(key)
        else:
            break
    icon_path = XPBAR_ICON.get(selected_key, None)
    return icon_path


def get_level(exp):
    level = math.floor(math.sqrt(exp / 2000))
    next_lavel = get_percentage_to_next_level(exp)
    # print(f"Level: {level} ({next_lavel}%)")
    return level, next_lavel



#MARK: XP
def get_xp_and_level_text(xp):
    xp = int(float(xp))
    level, next_lavel = get_level(exp=xp)

    str_span_font_size = '<span style="font-size:80%">'
    str_span_end = '</span>'

    display_text = f"Lv. {level} {str_span_font_size}({xp:,} xp){str_span_end}"

    try:
        size = ICON_SIZE
        icon_path = get_xp_icon(level_value=next_lavel)
        icon_html = make_icon_html(icon_path, size)
        icon_html = add_align_middle(icon_html)
        str_country_html = f'{icon_html} {display_text}'
        return str_country_html

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

    return display_text




#MARK: lifebar
def get_lifebar_icon(review_value):
    review_value = int(float(review_value))
    numeric_keys = sorted([int(key) for key in LIFEBAR_ICON.keys()])
    selected_key = str(numeric_keys[0])
    for key in numeric_keys:
        if key <= review_value:
            selected_key = str(key)
        else:
            break
    return LIFEBAR_ICON.get(selected_key, None)


#MARK: icon-review
def make_review_icon(review, cards_31day):
    size = ICON_SIZE

    cards_31day = int(float(cards_31day))
    perday = max(0, cards_31day // 31)

    if perday > 0 :
        review_completion_rate = int(max(0, min(100, (review/ perday) * 100)))
    else:
        review_completion_rate = 0
    icon_path = get_lifebar_icon(review_completion_rate)
    icon_html = make_icon_html(icon_path, size)
    return icon_html



#MARK:Review
def get_review_text(cards, time, month):
    is_mini_mode = False

    second = float(time) * 60
    review = int(float(cards))
    
    str_span_font_size = '<span style="font-size:80%">'
    str_span_end = '</span>'
    
    if review == 0:
        if is_mini_mode:
            display_text = f"{review:,} {str_span_font_size}(0s){str_span_end}"
        else:
            display_text = f"{review:,} rev {str_span_font_size}(0sec){str_span_end}"

    else:
        second_per_card = round(max(0, second // review))
        alert_emoji = ""
        if (IS_ARART_BY_REVIEW_SECONDS
            and second_per_card <= ARART_THRESHOLD
            and review > 100):
            alert_emoji = "🚨"

        if is_mini_mode:
            display_text = f"{review:,} {str_span_font_size}({second_per_card}s){str_span_end}"
        else:
            display_text = f"{review:,} rev {str_span_font_size}({alert_emoji}{second_per_card}sec){str_span_end}"

    try:
        icon_html = make_review_icon(review=review, cards_31day=month)
        icon_html = add_align_middle(icon_html)
        str_country_html = f'{icon_html} {display_text}'
        return str_country_html

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

    return display_text




#MARK:time-icon
def get_time_icon(time_value):
    time_value = int(time_value)
    numeric_keys = sorted([int(key) for key in TIME_FLAT_ICON_LIGHT.keys()])
    selected_key = str(numeric_keys[0])
    for key in numeric_keys:
        if key <= time_value:
            selected_key = str(key)
        else:
            break

    try:
        from aqt.theme import theme_manager
        if theme_manager.night_mode:
            result = TIME_FLAT_ICON_LIGHT.get(selected_key, None)
        else:
            result = TIME_FLAT_ICON_DARK.get(selected_key, None)

    except Exception as e:
        print("Leadearboard Error get_time_icon: ",e)
        result = TIME_FLAT_ICON_LIGHT.get(selected_key, None)

    size = ICON_SIZE
    icon_html = make_icon_html(result, size)

    return icon_html



#MARK:time
def get_time_text(time):
    minutes = int(float(time))
    hours = minutes // 60
    remaining_minutes = minutes % 60
    display_text = f"{hours:02}h {remaining_minutes:02}m"

    try:
        icon_html = get_time_icon(time_value=minutes)
        icon_html = add_align_middle(icon_html)
        str_time_html = f'{icon_html} {display_text}'

        return str_time_html

    except Exception as e:
        print(f"[{ADDON_NAME}] Error {e} ")


    return display_text



#MARK:icon-streaks
def get_tree_icon(streak):
    streak = int(streak)
    numeric_keys = sorted([int(key) for key in TREE_ICON.keys()])
    selected_key = str(numeric_keys[0])
    for key in numeric_keys:
        if key <= streak:
            selected_key = str(key)
        else:
            break
    result = TREE_ICON.get(selected_key, None)
    return result



#MARK:streaks
def is_repeating_number(streak):
    # ｿﾞﾛ目ﾁｪｯｸ
    str_streaks = str(streak)
    if len(str_streaks) >= 3:
        first_character = str_streaks[0]
        for character in str_streaks:
            if character != first_character:
                return False
        # ｿﾞﾛ目
        return True
    return False


def check_streaks(streak):
    if (streak != 0
        and (
        streak % 100 == 0
        or streak % 365 == 0
        or streak in [7, 31, 60]
        or is_repeating_number(streak))):
        return True

def get_streak_text(streak):
    is_mini_mode = False

    days = int(float(streak))

    years = days // 365
    remaining_days = days % 365
    months = 0
    for days_in_month in [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]:
        if remaining_days >= days_in_month:
            remaining_days -= days_in_month
            months += 1
        else:
            break
    streaks_emoji = ""
    if days > 0 and days % 365 == 0:
        streaks_emoji = "🍰"
    elif check_streaks(days):
        streaks_emoji = "🎉"
    years_text = f"{years}y " if years else ""
    months_text = f"{months}m " if months else ""
    remaining_days_text = f"{remaining_days}d " if remaining_days else "0d "

    is_long_text = False

    if not months and not years:
        all_days_text = f"{int(streak):,}d"
        remaining_days_text = ""
    else:
        all_days_text = f"<br>({int(streak):,}d)"
        is_long_text = True

    if is_mini_mode:
        all_days_text = f"{int(streak):,}d"
        display_text = f"{all_days_text}"
    else:
        display_text = f"{years_text}{months_text}{remaining_days_text}{all_days_text}{streaks_emoji}"

    if is_long_text:
        display_text = f'<span style="font-size:90%">{display_text}</span>'

    try:
        size = ICON_SIZE
        icon_path =  get_tree_icon(streak=days)
        icon_html = make_icon_html(icon_path, size)

        icon_html = add_align_middle(icon_html)

        # if not is_long_text:
        #     str_streaks_html = f'{icon_html} {display_text}'

        # else:
        str_streaks_html = make_multiple_box(icon_html, display_text)

        return str_streaks_html

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e} ")

    return display_text




#MARK:icon-31days
def get_orb_icon(cards_31day):
    cards_31day = int(cards_31day)
    numeric_keys = sorted([int(key) for key in ORB_ICON.keys()])
    selected_key = str(numeric_keys[0])
    for key in numeric_keys:
        if key <= cards_31day:
            selected_key = str(key)
        else:
            break
    result = ORB_ICON.get(selected_key, None)
    return result


#MARK:31days
def get_31days_text(month):
    is_mini_mode = False

    cards_31day = int(float(month))
    perday = max(0, cards_31day // 31)

    if is_mini_mode:
        display_text = f"{int(perday):,}/d"
    else:
        # display_text = f"{int(perday):,} /d ({int(cards_31day):,} rev)"
        display_text = (f'{int(perday):,} /d'
                        f'<br>'
                        f'<span style="font-size:80%">'
                        f'({int(cards_31day):,} rev)'
                        f'</span>'
                        )

    try:
        size = ICON_SIZE
        icon_path =  get_orb_icon(int(perday))
        icon_html = make_icon_html(icon_path, size)

        icon_html = add_align_middle(icon_html)

        # str_31days_html = f'{icon_html} {display_text}'

        str_31days_html = make_multiple_box(icon_html, display_text)


        return str_31days_html

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

    return display_text