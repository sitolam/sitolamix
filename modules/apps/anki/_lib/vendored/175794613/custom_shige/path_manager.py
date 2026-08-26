# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import os

ADDON_FOLDER = os.path.dirname(os.path.dirname(__file__))
MEDIA_FOLDER = os.path.join(ADDON_FOLDER, "media_files")

# __init__.py
MENU_NAME = '&Leaderboard'
# MENU_NAME = '&ShigeBoard'
ADDON_ID = "175794613"
# ADDON_ID = "41708974"
ADD_ON_NAME = "Anki_Leaderboard"
PATREON_URL = "http://patreon.com/Shigeyuki"


TRANSLATE_MENU = "Leaderboard_menu"
HOW_TO_USE_TR = "how_to_use_tr"

# WEBBROWSER_OPEN_GITHUB_URL = 'https://github.com/ThoreBor/Anki_Leaderboard/issues'
# WEBBROWSER_OPEN_GITHUB_URL = 'https://new.reddit.com/user/Shige-yuki'
WEBBROWSER_OPEN_GITHUB_URL = "https://new.reddit.com/r/Anki/comments/1b0eybn/simple_fix_of_broken_addons_for_the_latest_anki/"


CHECK_INFO_URL = 'https://ankileaderboardinfo.netlify.app' # 使ってない
# CHECK_INFO_URL = '🟢' #TODO : 通知用のURLの追加

# api_connect.py
# POST_REQUEST = "http://127.0.0.1:8000/api/v2/"
# POST_REQUEST = "https://shigeyuki.pythonanywhere.com/api/v2/"
POST_REQUEST = "https://shigeyuki.pythonanywhere.com/api/v2/"


LEADERBOARD_URL = "https://shigeyuki.pythonanywhere.com/"

# python3 home/Shigeyuki/ShigeLeaderboad/api2.py/
# python3 home/Shigeyuki/ShigeLeaderboad/api2.py

PRIVACY_POLICY = "https://shigeyuki.pythonanywhere.com/privacy/"

ICON_IMAGES_URL = "https://shigeyuki.pythonanywhere.com/static/user_icons/"


ONLINE_DOT = []
ONLINE_DOT_01 = os.path.join(MEDIA_FOLDER, "others", "online_dot_01.png") # 0 enable
ONLINE_DOT.append(ONLINE_DOT_01)
ONLINE_DOT_02 = os.path.join(MEDIA_FOLDER, "others", "online_dot_02.png") # 1 disable
ONLINE_DOT.append(ONLINE_DOT_02)


TIME_FLAT_ICON_LIGHT = {}
TIME_FLAT_ICON_LIGHT["0"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "0.png")
TIME_FLAT_ICON_LIGHT["10"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "10.png")
TIME_FLAT_ICON_LIGHT["20"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "20.png")
TIME_FLAT_ICON_LIGHT["30"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "30.png")
TIME_FLAT_ICON_LIGHT["40"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "40.png")
TIME_FLAT_ICON_LIGHT["50"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "50.png")
TIME_FLAT_ICON_LIGHT["60"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "60_1.png")
TIME_FLAT_ICON_LIGHT["80"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "80.png")
TIME_FLAT_ICON_LIGHT["100"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "100.png")
TIME_FLAT_ICON_LIGHT["120"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "120_2.png")
TIME_FLAT_ICON_LIGHT["140"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "140.png")
TIME_FLAT_ICON_LIGHT["160"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "160.png")
TIME_FLAT_ICON_LIGHT["180"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "180_3.png")
TIME_FLAT_ICON_LIGHT["200"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "200.png")
TIME_FLAT_ICON_LIGHT["220"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "220.png")
TIME_FLAT_ICON_LIGHT["240"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "240_4.png")
TIME_FLAT_ICON_LIGHT["260"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "260.png")
TIME_FLAT_ICON_LIGHT["280"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "280.png")
TIME_FLAT_ICON_LIGHT["300"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "300_5.png")
TIME_FLAT_ICON_LIGHT["360"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "360_6.png")
TIME_FLAT_ICON_LIGHT["420"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "420_7.png")
TIME_FLAT_ICON_LIGHT["480"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "480_8.png")
TIME_FLAT_ICON_LIGHT["540"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "540_9.png")
TIME_FLAT_ICON_LIGHT["600"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "600_10.png")
TIME_FLAT_ICON_LIGHT["660"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "660_11.png")
TIME_FLAT_ICON_LIGHT["720"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_dark", "720_12.png")

TIME_FLAT_ICON_DARK = {}
TIME_FLAT_ICON_DARK["0"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "0.png")
TIME_FLAT_ICON_DARK["10"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "10.png")
TIME_FLAT_ICON_DARK["20"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "20.png")
TIME_FLAT_ICON_DARK["30"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "30.png")
TIME_FLAT_ICON_DARK["40"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "40.png")
TIME_FLAT_ICON_DARK["50"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "50.png")
TIME_FLAT_ICON_DARK["60"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "60_1.png")
TIME_FLAT_ICON_DARK["80"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "80.png")
TIME_FLAT_ICON_DARK["100"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "100.png")
TIME_FLAT_ICON_DARK["120"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "120_2.png")
TIME_FLAT_ICON_DARK["140"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "140.png")
TIME_FLAT_ICON_DARK["160"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "160.png")
TIME_FLAT_ICON_DARK["180"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "180_3.png")
TIME_FLAT_ICON_DARK["200"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "200.png")
TIME_FLAT_ICON_DARK["220"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "220.png")
TIME_FLAT_ICON_DARK["240"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "240_4.png")
TIME_FLAT_ICON_DARK["260"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "260.png")
TIME_FLAT_ICON_DARK["280"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "280.png")
TIME_FLAT_ICON_DARK["300"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "300_5.png")
TIME_FLAT_ICON_DARK["360"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "360_6.png")
TIME_FLAT_ICON_DARK["420"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "420_7.png")
TIME_FLAT_ICON_DARK["480"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "480_8.png")
TIME_FLAT_ICON_DARK["540"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "540_9.png")
TIME_FLAT_ICON_DARK["600"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "600_10.png")
TIME_FLAT_ICON_DARK["660"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "660_11.png")
TIME_FLAT_ICON_DARK["720"] = os.path.join(MEDIA_FOLDER, "time_icons", "flat_light", "720_12.png")


WEATHER_ICON = {}
WEATHER_ICON["9"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Light", "9.png")
WEATHER_ICON["10"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Light", "10.png")
WEATHER_ICON["25"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Light", "25.png")
WEATHER_ICON["40"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Light", "40.png")
WEATHER_ICON["55"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Light", "55.png")
WEATHER_ICON["70"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Light", "70.png")
WEATHER_ICON["85"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Light", "85.png")

WEATHER_ICON_DARK = {}
WEATHER_ICON_DARK["9"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Dark", "9.png")
WEATHER_ICON_DARK["10"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Dark", "10.png")
WEATHER_ICON_DARK["25"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Dark", "25.png")
WEATHER_ICON_DARK["40"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Dark", "40.png")
WEATHER_ICON_DARK["55"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Dark", "55.png")
WEATHER_ICON_DARK["70"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Dark", "70.png")
WEATHER_ICON_DARK["85"] = os.path.join(MEDIA_FOLDER, "weather_icons", "Dark", "85.png")

TREE_ICON = {}
TREE_ICON["0"] = os.path.join(MEDIA_FOLDER, "streaks", "0.png")
TREE_ICON["1"] = os.path.join(MEDIA_FOLDER, "streaks", "1.png")
TREE_ICON["2"] = os.path.join(MEDIA_FOLDER, "streaks", "2.png")
TREE_ICON["3"] = os.path.join(MEDIA_FOLDER, "streaks", "3.png")
TREE_ICON["4"] = os.path.join(MEDIA_FOLDER, "streaks", "4.png")
TREE_ICON["5"] = os.path.join(MEDIA_FOLDER, "streaks", "5.png")
TREE_ICON["6"] = os.path.join(MEDIA_FOLDER, "streaks", "6.png")
TREE_ICON["7"] = os.path.join(MEDIA_FOLDER, "streaks", "7.png")
TREE_ICON["14"] = os.path.join(MEDIA_FOLDER, "streaks", "8.png")
TREE_ICON["21"] = os.path.join(MEDIA_FOLDER, "streaks", "9.png")
TREE_ICON["31"] = os.path.join(MEDIA_FOLDER, "streaks", "10.png")

TREE_ICON["60"] = os.path.join(MEDIA_FOLDER, "streaks", "10-02.png")
TREE_ICON["100"] = os.path.join(MEDIA_FOLDER, "streaks", "10-11.png")

TREE_ICON["365"] = os.path.join(MEDIA_FOLDER, "streaks", "11.png")
TREE_ICON["730"] = os.path.join(MEDIA_FOLDER, "streaks", "12.png")
TREE_ICON["1095"] = os.path.join(MEDIA_FOLDER, "streaks", "13.png")

LIFEBAR_ICON = {}
LIFEBAR_ICON["0"] = os.path.join(MEDIA_FOLDER, "life_bar", "0.png")
LIFEBAR_ICON["15"] = os.path.join(MEDIA_FOLDER, "life_bar", "15.png")
LIFEBAR_ICON["30"] = os.path.join(MEDIA_FOLDER, "life_bar", "30.png")
LIFEBAR_ICON["45"] = os.path.join(MEDIA_FOLDER, "life_bar", "45.png")
LIFEBAR_ICON["60"] = os.path.join(MEDIA_FOLDER, "life_bar", "60.png")
LIFEBAR_ICON["75"] = os.path.join(MEDIA_FOLDER, "life_bar", "75.png")
LIFEBAR_ICON["90"] = os.path.join(MEDIA_FOLDER, "life_bar", "90.png")
LIFEBAR_ICON["100"] = os.path.join(MEDIA_FOLDER, "life_bar", "100.png")

ORB_ICON = {}
for i in range(0, 2991, 10):
    ORB_ICON[str(i)] = os.path.join(MEDIA_FOLDER, "orb_128px", f"{i}.png")

for i in range(3000, 10001, 1000):
    ORB_ICON[str(i)] = os.path.join(MEDIA_FOLDER, "orb_128px", f"{i}.png")

XPBAR_ICON = {}
XPBAR_ICON["0"] = os.path.join(MEDIA_FOLDER, "xp_bar", "0.png")
XPBAR_ICON["15"] = os.path.join(MEDIA_FOLDER, "xp_bar", "15.png")
XPBAR_ICON["30"] = os.path.join(MEDIA_FOLDER, "xp_bar", "30.png")
XPBAR_ICON["45"] = os.path.join(MEDIA_FOLDER, "xp_bar", "45.png")
XPBAR_ICON["60"] = os.path.join(MEDIA_FOLDER, "xp_bar", "60.png")
XPBAR_ICON["75"] = os.path.join(MEDIA_FOLDER, "xp_bar", "75.png")
XPBAR_ICON["90"] = os.path.join(MEDIA_FOLDER, "xp_bar", "90.png")
XPBAR_ICON["100"] = os.path.join(MEDIA_FOLDER, "xp_bar", "100.png")


# Discord

DISCORD_INVITE_URL = "https://discord.gg/XUrGSX9UME"
DISCORD_ICON = os.path.join(MEDIA_FOLDER, "others", "discord_icon.png")

# others
# Skorp24, CC BY-SA 4.0 <https://creativecommons.org/licenses/by-sa/4.0>, via Wikimedia Commons
# https://commons.wikimedia.org/wiki/File:Loading_icon_cropped.gif
NOW_LOADING_GIF = os.path.join(MEDIA_FOLDER, "others", "Loading_icon_cropped.png")
NOW_LOADING_GIF_DARK = os.path.join(MEDIA_FOLDER, "others", "Loading_icon_cropped_02.png")

LEADERBOAD_ICON = os.path.join(MEDIA_FOLDER, "others", "anki_leaderboard_icon.png")
