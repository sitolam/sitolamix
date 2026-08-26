import datetime
import html

from aqt import mw

from .lb_home_tools import make_icon_html, add_align_middle
from ..config_local import get_local_config

from ..custom_shige.country_dict import COUNTRY_FLAGS, COUNTRY_LIST_V2
from ..create_icon import create_leaderboard_icon
from ..chat_urls import DICT_CHAT_URLS
from ..path_manager import ADDON_NAME

def calculate_country():
    country_html = ""
    country_options = ""


    each_country_reviews = country_data_manager.each_country_reviews
    if not each_country_reviews:
        return ""

    config = mw.addonManager.getConfig(__name__)

    lo_config = get_local_config()
    home_selected_country = lo_config.get("home_selected_country")

    if home_selected_country and home_selected_country in COUNTRY_LIST_V2.keys():
        user_country = home_selected_country
    else:
        user_country = config["country"].replace(" ", "")
        if user_country not in COUNTRY_LIST_V2.keys():
            user_country = None

    # sorted_country_data = sorted(each_country_reviews, key=lambda item: item[1][0], reverse=True)
    sorted_country_data = sorted(each_country_reviews.items(), key=lambda item: item[1][0], reverse=True)

    rank_index = 0
    now_country_name = ""
    for index, (trim_country_name, item) in enumerate(sorted_country_data):

        each_country_reviews = item[0]
        each_country_total_users = item[1]

        if trim_country_name not in COUNTRY_LIST_V2.keys():
            continue

        medal = ""
        rank_index += 1
        if rank_index == 1:
            medal = "🥇"
        elif rank_index == 2:
            medal = "🥈"
        elif rank_index == 3:
            medal = "🥉"

        country_time = get_country_time(trim_country_name)

        active_users = each_country_total_users
        month = each_country_reviews
        if isinstance(month, int):
            month = f"{month:,}"
        country_score = f"| {active_users} users | {month} rev | {country_time} "

        display_country_name = COUNTRY_LIST_V2[trim_country_name]
        display_name = f"{medal}{rank_index}. {display_country_name} {country_score}"

        flag_icon_file_path = COUNTRY_FLAGS.get(trim_country_name, "pirate.png")
        country_icon = create_leaderboard_icon(
                            file_name=flag_icon_file_path,
                            icon_type="flag",
                            is_need_only_path=True)

        country_icon_html = make_icon_html(country_icon, 20)
        country_icon_html = add_align_middle(country_icon_html)

        # country_icon_data = make_icon_html(country_icon, 20, only_data=True)

        option_inner_html = (
            f'{country_icon_html} '
            f'{display_name}'
        )

        if user_country == trim_country_name:
            now_country_name = option_inner_html

        try:
            country_options += (
                                f"""<a onclick="pycmd('shige_leaderboard_select_country:{trim_country_name}')">"""
                                f"""{option_inner_html}</a>"""
                                )
        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {e}")

        try:
            if active_users >= 100 and trim_country_name not in DICT_CHAT_URLS.keys():
                print(f"[{ADDON_NAME}] >>> {trim_country_name}: {active_users} users ")

        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {e}")


    if country_options:

        str_channel_shield = ""
        try:
            from ..make_shield import make_channel_shield
            str_channel_shield = make_channel_shield(user_country)
        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {e} ")

        country_html += f"""
<div class="dropdown" style="display:inline;">
    <button class="dropdown-button">{now_country_name}</button>
    <div class="dropdown-content" style="text-align:left;">
    <div class="dropdown-title">country</div>
        {country_options}
    </div>
    {str_channel_shield}
</div>
"""

    return country_html


#MARK:CountryDataManager

class CountryDataManager:
    def __init__(self):
        self.reset_country_data()

    def reset_country_data(self):
        self.country_cache = []
        self.each_country_counter = {}
        self.each_country_reviews = {}

    def save_country_data(self, country: str, sync_date, month, start_day_minus_seven):
        # if not country or not sync_date or not month or not start_day_minus_seven:
        if not country or not sync_date:
            return

        trim_country_name = country.replace(" ", "")

        each_country_total_users = self.each_country_counter.get(trim_country_name, 0)
        each_country_total_users += 1

        country_data = self.each_country_reviews.get(trim_country_name, [0, 0])

        if sync_date > start_day_minus_seven:
            each_country_reviews = country_data[0] + int(month)
        else:
            each_country_reviews = country_data[0]

        self.each_country_counter[trim_country_name] = each_country_total_users
        self.each_country_reviews[trim_country_name] = [each_country_reviews, each_country_total_users]


country_data_manager = CountryDataManager()


def get_country_time(country):
    try:
        import sys
        import os
        import importlib.util

        if 'tzdata' not in sys.modules:
            addon_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
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
        # pip install --target="...\bundle\tzdata"
        from zoneinfo import ZoneInfo
    except Exception as e:
        print(f"Error importing ZoneInfo: {e}")
        return ""

    try:
        from ..custom_shige.country_dict import COUNTRY_TIMEZONES
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
