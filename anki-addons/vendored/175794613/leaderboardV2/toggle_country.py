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
from aqt import QTimer, mw
from aqt import QComboBox

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .leaderboardV2 import RebuildLeaderbord, PaginationBoard

from ..custom_shige.country_dict import COUNTRY_FLAGS, COUNTRY_LIST, COUNTRY_LIST_V2
from ..create_icon import create_leaderboard_icon
from ..custom_shige.searchable_combobox import SearchableComboBox


def set_toggle_country(rebuild: "RebuildLeaderbord", table_widget:"PaginationBoard"):

    toggle_country = SearchableComboBox(table_widget)
    toggle_country.setSizeAdjustPolicy(QComboBox.SizeAdjustPolicy.AdjustToContents)
    toggle_country.setMaxVisibleItems(20)
    toggle_country.setObjectName("toggle_country")

    table_widget.custom_layout.addWidget(toggle_country)
    # table_widget.custom_layout.addStretch()

    def switch_country(index):
        if index is None:
            index = toggle_country.currentIndex()
        league_name = toggle_country.itemData(index)
        rebuild.country_cache = rebuild.all_country_cache.get(league_name, [])
        table_widget.resetPagination(rebuild.country_cache, rebuild.page_size)
        table_widget.goToFirstPage()
        # QTimer.singleShot(0, lambda: table_widget.table_widget.verticalScrollBar().setValue(0))

        try:
            if league_name:
                from .discord_button import add_discord_button_toggle
                add_discord_button_toggle(table_widget.custom_layout, league_name)
        except:
            pass


    sorted_country_data = sorted(rebuild.each_country_reviews.items(), key=lambda item: item[1][0], reverse=True)

    # for country_name in COUNTRY_LIST:
    rank_index = 0
    for index, (trim_country_name, item)  in  enumerate(sorted_country_data):
        each_country_reviews = item[0]
        each_country_total_users = item[1]

        if not trim_country_name in COUNTRY_LIST_V2.keys():
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
        country_icon = create_leaderboard_icon(file_name=flag_icon_file_path,
                                            icon_type="flag")

        toggle_country.addItem(country_icon, display_name, trim_country_name)

    current_country = rebuild.config.get("country", []) #type: str
    if current_country:
        current_country = current_country.replace(" ", "")

    index = toggle_country.findData(current_country)
    if index != -1:
        toggle_country.setCurrentIndex(index)
        switch_country(index)

    toggle_country.currentIndexChanged.connect(switch_country)


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
        from zoneinfo import ZoneInfo
    except Exception as e:
        print(f"Error importing ZoneInfo: {e}")
        return ""

    # pip install --target="C:\Users\shigg\AppData\Roaming\Anki2\addons21\Anki Leaderboard (Fixed by Shige)\bundle\tzdata" tzdata

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

