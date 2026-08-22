# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

from aqt import mw
from aqt.utils import openLink
from aqt.qt import QHBoxLayout, QPushButton, QIcon, Qt

from ..shige_pop.button_manager import mini_button
from ..custom_shige.path_manager import DISCORD_ICON, DISCORD_INVITE_URL

def add_discord_button(layout:QHBoxLayout, url=DISCORD_INVITE_URL, tooltip="Discord"):
    config = mw.addonManager.getConfig(__name__)
    if config.get("discord_button", True):
        discord_button = QPushButton()
        discord_icon =  QIcon(DISCORD_ICON)
        discord_button.setIcon(discord_icon)
        discord_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        if tooltip:
            discord_button.setToolTip(tooltip)
        discord_button.clicked.connect(lambda: openLink(url))
        mini_button(discord_button)
        layout.addWidget(discord_button)


def add_discord_button_toggle(layout: QHBoxLayout, country_name):
    # print(country_name)
    from ..chat_urls import DICT_CHAT_URLS
    country_dict = DICT_CHAT_URLS

    config = mw.addonManager.getConfig(__name__)
    if not config.get("discord_button", True):
        return


    discord_button = None
    for i in range(layout.count()):
        button = layout.itemAt(i).widget()
        if isinstance(button, QPushButton) and button.objectName() == "discordButton":
            discord_button = button
            break

    if country_name in country_dict:
        url = country_dict[country_name]["url"]
        tooltip = country_dict[country_name]["tooltip"]

        if discord_button is None:
            discord_button = QPushButton()
            discord_button.setObjectName("discordButton")
            icon = QIcon(DISCORD_ICON)
            discord_button.setIcon(icon)
            discord_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            mini_button(discord_button)
            layout.addWidget(discord_button)

        discord_button.setToolTip(tooltip)
        try:
            discord_button.clicked.disconnect()
        except TypeError:
            pass
        discord_button.clicked.connect(lambda: openLink(url))
        discord_button.show()
    else:
        if discord_button:
            discord_button.hide()