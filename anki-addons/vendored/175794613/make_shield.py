# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import urllib.parse

from aqt import mw

from .chat_urls import DICT_CHAT_URLS, STR_GLOBAL_CHANNEL
from .path_manager import ADDON_NAME


def make_shields_io_html():
    try:
        config = mw.addonManager.getConfig(__name__)
        is_show_discord_button = config.get("discord_button", True)
        if not is_show_discord_button:
            return ""

        from . import get_startup_shige_leaderboard
        startup = get_startup_shige_leaderboard()
        active_users = startup.int_active_users

        if active_users == 0:
            return ""

        active_users_str = f"{active_users:,}"

        svg_url = (
            "https://img.shields.io/badge/"
            f"Active%20Users-{active_users_str.replace(',', '%2C')}"
            # f"Learners-{active_users_str.replace(',', '%2C')}"
            "-brightgreen?logo=anki&logoColor=fff"
        )

        html_tag = f'<img src="{svg_url}">'

        str_global_channel = STR_GLOBAL_CHANNEL

        html_tag += f"""
&nbsp;
<a href="{str_global_channel}" style="text-decoration: none;">
    <img src="https://img.shields.io/discord/1215610525212344350?label=Discord&logo=discord&logoColor=fff">
</a>
"""

        html_tag = f"""<span style="vertical-align: middle;">{html_tag}</span>"""

        return html_tag

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e} ")
        return ""



def make_channel_shield(str_channel_key:str):
    try:
        config = mw.addonManager.getConfig(__name__)
        is_show_discord_button = config.get("discord_button", True)
        if not is_show_discord_button:
            return ""

        str_channel_key = str_channel_key.replace(" ", "")

        if str_channel_key in DICT_CHAT_URLS:

            str_channel_url = DICT_CHAT_URLS[str_channel_key]["url"]
            str_channel_name = DICT_CHAT_URLS[str_channel_key]["channel"]

            str_channel_name = str_channel_name.replace("-", "--")
            encoded_channel_name = urllib.parse.quote(str_channel_name)

            svg_url = (
                f"https://img.shields.io/badge/{encoded_channel_name}-%235865F2.svg?"
                f"&logo=discord&logoColor=white"
            )

            html_tag = f"""
&nbsp;
<a href="{str_channel_url}" style="text-decoration: none;">
    <img src="{svg_url}">
</a>
"""
            html_tag = f"""<span style="vertical-align: middle;">{html_tag}</span>"""

            return html_tag

        return ""

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")
        return ""