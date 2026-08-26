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


from os.path import join, dirname, exists
from os import makedirs
import json

def get_color_config() -> dict:
    try:
        from aqt.theme import theme_manager
        nightmode = theme_manager.night_mode
    except:
        nightmode = False

    addon_path = dirname(__file__)
    user_files_dir = join(addon_path, "user_files")
    color_config_path = join(user_files_dir, "colors.json")

    if not exists(user_files_dir):
        makedirs(user_files_dir)
    if not exists(color_config_path):
        with open(color_config_path, "w") as colors_file:
            json.dump(NEW_DEFAULT_COLORS, colors_file, indent=4)

    with open(color_config_path, "r") as colors_file:
        color_data = colors_file.read()
        colors_themes = json.loads(color_data)
        colors = colors_themes["dark"] if nightmode else colors_themes["light"]

    return colors


NEW_DEFAULT_COLORS ={
    "light": {
        "USER_COLOR": "#ceffce",
        "FRIEND_COLOR": "#d9edff",
        "GOLD_COLOR": "#fffab3",
        "SILVER_COLOR": "#d5d5d5",
        "BRONZE_COLOR": "#f8d1c0",
        "ROW_LIGHT": "#ffffff",
        "ROW_DARK": "#f5f5f5",
        "LEAGUE_TOP": "#e1fff4",
        "LEAGUE_BOTTOM": "#f7b8b8",
        "LEAGUE_BOTTOM_USER": "#f7b8b8"
    },
    "dark": {
        "USER_COLOR": "#4a614d",
        "FRIEND_COLOR": "#334170",
        "GOLD_COLOR": "#95923a",
        "SILVER_COLOR": "#7d7d7d",
        "BRONZE_COLOR": "#8c6549",
        "ROW_LIGHT": "#3A3A3A",
        "ROW_DARK": "#2F2F31",
        "LEAGUE_TOP": "#365255",
        "LEAGUE_BOTTOM": "#582828",
        "LEAGUE_BOTTOM_USER": "#582828"
    }
}