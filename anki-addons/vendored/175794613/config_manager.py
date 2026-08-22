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

from aqt import mw
from aqt.utils import tooltip

SYNC_CONFIG_NAME = "shige_Anki_leaderboard_config"
SYNC_MULTIPLE_DEFAULT = False

def write_config(name, value):
    config = mw.addonManager.getConfig(__name__)
    config_content = {
        "username": config["username"],
        "friends": config["friends"],
        "newday": config["newday"],
        "current_group": config["current_group"],
        "groups": config["groups"],
        "country": config["country"],
        "scroll": config["scroll"],
        "tab": config["tab"],
        "authToken": config["authToken"],
        "achievement": config["achievement"],
        "sortby": config["sortby"],
        "hidden_users": config["hidden_users"],
        "homescreen": config["homescreen"],
        "autosync": config["autosync"],
        "maxUsers": config["maxUsers"],
        "focus_on_user": config["focus_on_user"],
        "import_error": config["import_error"],
        "show_medals": config["show_medals"],
        "notification_id": config["notification_id"],
        "homescreen_data": config["homescreen_data"],
        "medal_users": config["medal_users"],

        "shige_chang_log_day": config.get("shige_chang_log_day",""),
        "show_home_buttons": config.get("show_home_buttons", True),
        "add_pic_country_and_league": config.get("add_pic_country_and_league", True),
        "sync_multiple_device" : config.get("sync_multiple_device", SYNC_MULTIPLE_DEFAULT),
        "size_multiplier" : config.get("size_multiplier", 1.2),
        "zoom_enable":config.get("zoom_enable", True),
        "board_size": config.get("board_size", []),
        "set_font_family" : config.get("set_font_family", None),

        "hide_all_users_name" : config.get("hide_all_users_name", False),
        "show_your_name" : config.get("show_your_name", False),
        "board_position": config.get("board_position", []),

        "gamification_mode" : config.get("gamification_mode", True),
        "allways_on_top" : config.get("allways_on_top", False),
        "start_yesterday" : config.get("start_yesterday", True),
        "is_online_dot" : config.get("is_online_dot", True),

        "rate_and_donation_buttons" : config.get("rate_and_donation_buttons", True),
        "mini_mode" : config.get("mini_mode", False),
        "discord_button": config.get("discord_button", True)
    }

    config_content[name] = value
    mw.addonManager.writeConfig(__name__, config_content)
    save_sync_config(config_content)


def save_sync_config(config_content):
    config = mw.addonManager.getConfig(__name__)

    if config.get("sync_multiple_device", SYNC_MULTIPLE_DEFAULT):
        # ｻｰﾊﾞｰに保存しない
        config_content["homescreen_data"] = []
        config_content["medal_users"] = []
        mw.col.set_config(SYNC_CONFIG_NAME, config_content) # ｻｰﾊﾞｰへ保存


def local_config_overwritten_by_server_config():
    # Confingをｵﾝﾗｲﾝからﾛｰｶﾙへ読み込んで上書き
    sync_config = mw.col.get_config(SYNC_CONFIG_NAME, default=None) # sync

    if sync_config:
        if sync_config.get("username", "") == "" or sync_config.get("authToken", None) == None:
            return
        config = mw.addonManager.getConfig(__name__) # ﾛｰｶﾙ
        sync_config["homescreen_data"] = config["homescreen_data"] # ﾛｰｶﾙ 上書きしない
        sync_config["medal_users"] = config["medal_users"] # ﾛｰｶﾙ 上書きしない
        sync_config["sync_multiple_device"] = config.get("sync_multiple_device", SYNC_MULTIPLE_DEFAULT) # ﾛｰｶﾙ 上書きしない

        mw.addonManager.writeConfig(__name__, sync_config) # ﾛｰｶﾙをｻｰﾊﾞｰで上書き保存
        tooltip("Success! :-)")
    else:
        tooltip("Error: No data on AnkiWeb server :-/")


# import os
# import json
# from aqt import QWidget, QVBoxLayout, QTextEdit, QHBoxLayout, QPushButton, QAction, qconnect

# def test_func():
#     # test-func ----------
#     if True:
#         current_file_path = os.path.abspath(__file__)
#         target_file_path = r"C:/Users/shigg/AppData/Roaming/Anki2/addons21/Anki Leaderboard (Fixed by Shige)/config_manager.py"
#         if not current_file_path == target_file_path:
#             return
#         class DisplayWindow(QWidget):
#             def __init__(self, data):
#                 super().__init__()
#                 self.initUI(data)

#             def initUI(self, data):
#                 self.setWindowTitle('Display Window')
#                 self.setGeometry(100, 100, 400, 300)

#                 layout = QVBoxLayout()
#                 self.text_edit = QTextEdit(self)
#                 # self.text_edit.setText(text)
#                 self.text_edit.setText(json.dumps(data, indent=4))

#                 layout.addWidget(self.text_edit)

#                 button_layout = QHBoxLayout()
#                 self.ok_button = QPushButton("OK", self)
#                 self.cancel_button = QPushButton("Cancel", self)
#                 button_layout.addWidget(self.ok_button)
#                 button_layout.addWidget(self.cancel_button)
#                 layout.addLayout(button_layout)

#                 self.ok_button.clicked.connect(self.save_json)
#                 self.cancel_button.clicked.connect(self.close)

#                 self.setLayout(layout)

#             def save_json(self):
#                 try:
#                     conf = json.loads(self.text_edit.toPlainText())
#                     mw.col.set_config(SYNC_CONFIG_NAME, conf)
#                     print(type(conf))
#                     print("save date", conf)
#                     self.close()
#                 except json.JSONDecodeError:
#                     print("Invalid JSON format")

#         test_func = QAction("debug_func", mw)
#         def test_func_action():
#             f = mw.col.get_config(SYNC_CONFIG_NAME, default=None)
#             print(type(f))
#             print(f)
#             mw.shige_leaderboard_sync_config_test_func = DisplayWindow(f)
#             mw.shige_leaderboard_sync_config_test_func.show()

#         qconnect(test_func.triggered, test_func_action)
#         mw.pokemenu.addAction(test_func)