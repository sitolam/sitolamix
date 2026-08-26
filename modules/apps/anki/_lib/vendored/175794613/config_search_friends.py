# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import sys

from aqt import QHBoxLayout, QSizePolicy, mw, QDialog, QVBoxLayout, QPushButton, QLabel
from aqt.utils import openLink
from aqt.operations import QueryOp
from anki.utils import pointVersion

from .api_connect import getRequest
from .config_manager import write_config
from .custom_shige.searchable_combobox import SearchableComboBox
from .path_manager import ADDON_NAME

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from config import start_config


class SearchFriendWindow(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.start_config = parent # type: start_config
        if parent == None:
            return
        self.username_list = None

        self.setWindowTitle("Search Users")
        self.setGeometry(100, 100, 300, 100)

        self.vbox_layout = QVBoxLayout()

        self.search_input = SearchableComboBox(self)
        self.vbox_layout.addWidget(self.search_input)


        self.result_label = QLabel(self)
        self.result_label.setText("Now loading...")
        self.vbox_layout.addWidget(self.result_label)

        hbox = QHBoxLayout()

        self.search_button = QPushButton("Add Friend", self)
        self.search_button.clicked.connect(self.addFriend)
        self.search_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        self.search_button.setStyleSheet("QPushButton { padding: 2px; }")
        hbox.addWidget(self.search_button)

        self.remove_button = QPushButton("Remove Friend", self)
        self.remove_button.clicked.connect(self.removeFriend)
        self.remove_button.setStyleSheet("QPushButton { padding: 2px; }")
        self.remove_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        hbox.addWidget(self.remove_button)


        self.user_info_button = QPushButton("UserInfo", self)
        self.user_info_button.clicked.connect(self.on_user_info)
        self.user_info_button.setStyleSheet("QPushButton { padding: 2px; }")
        self.user_info_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        hbox.addWidget(self.user_info_button)


        self.wiki_button = QPushButton("📖Wiki")
        self.wiki_button.setStyleSheet("QPushButton { padding: 2px; }")
        self.wiki_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        self.wiki_button.clicked.connect(lambda: openLink(
            "https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html#friends"))
        hbox.addWidget(self.wiki_button)


        self.vbox_layout.addLayout(hbox)

        self.setLayout(self.vbox_layout)

        self.get_users_list()
        self.center()

    def center(self):
        if self.parent():
            parent_rect = self.start_config.geometry()
            self_rect = self.geometry()
            x = parent_rect.x() + (parent_rect.width() - self_rect.width()) // 2
            y = parent_rect.y() + (parent_rect.height() - self_rect.height()) // 2
            self.move(x, y)

    def get_users_list(self):
        op = QueryOp(
            parent=self,
            op=self.populate_usernames,
            success=self.additems_usernames
        )
        if pointVersion() >= 231000:
            op.without_collection()
        op.run_in_background()


    def populate_usernames(self, col):
        response = getRequest("users/", False)
        if response:
            all_usernames = response.json()

            size_bytes = sys.getsizeof(all_usernames)
            size_mb = size_bytes / (1024 * 1024)
            print(f"[{ADDON_NAME}] users/ size: {size_mb:.2f} MB")

            # config = mw.addonManager.getConfig(__name__)
            # friends_list = config.get("friends", [])
            # hiddens_list = config.get("hidden_users", [])
            # self.username_list = [item for item in all_usernames if item not in friends_list and item not in hiddens_list]


            # self.username_list = [item for item in all_usernames]
            simple_username_list = []
            for username in all_usernames:
                simple_username_list.append(username)
            self.username_list = simple_username_list

            # self.username_list = sorted(self.username_list, key=str.lower)

            self.username_list.reverse()

            # self.search_input.addItems(self.username_list)

    def additems_usernames(self, result):
        if self.username_list:
            # self.username_list = sorted(self.username_list, key=str.lower)
            self.search_input.addItems(self.username_list)
            self.result_label.setText("Please enter a user name.")
            self.search_input.setCurrentText("")
        else:
            self.result_label.setText("Hmmm, loading failed :-/")
            self.search_input.setCurrentText("")


    def addFriend(self):
        username = self.search_input.currentText()
        config = mw.addonManager.getConfig(__name__)

        if self.username_list:
            if config['username'] and config['username'] not in config['friends']:
                config['friends'].append(config['username'])

            if username in self.username_list and username not in config['friends']:
                config['friends'].append(username)
                write_config("friends", config['friends'])
                self.result_label.setText(f"{username} is now your friend! :-)")
                if hasattr(self.start_config, 'dialog') and hasattr(self.start_config.dialog, 'friend_username'):
                    self.start_config.dialog.friend_username.setText("")
                    self.start_config.updateFriendsList(sorted(config["friends"], key=str.lower))
            else:
                self.result_label.setText("Already added or name not found :-/")


    def removeFriend(self):
        username = self.search_input.currentText()
        config = mw.addonManager.getConfig(__name__)
        if username in config['friends']:
            config['friends'].remove(username)
            write_config("friends", config["friends"])
            self.result_label.setText(f"{username} was removed from your friendlist.")
            if hasattr(self.start_config, 'updateFriendsList'):
                self.start_config.updateFriendsList(sorted(config["friends"], key=str.lower))
        else:
            self.result_label.setText(f"{username} is not in your friendlist.")




    def on_user_info(self):
        username = self.search_input.currentText()
        if username:
            from .userInfo import start_user_info
            self.shige_user_info = start_user_info(username, False)
            self.shige_user_info.show()
            self.shige_user_info.raise_()
            self.shige_user_info.activateWindow()



# # 既存の addFriend 関数を修正して新しいウィンドウを表示する
# def addFriend(self):
#     search_window = SearchFriendWindow(self)
#     search_window.exec()
    
#     username = self.dialog.friend_username.text()
#     config = mw.addonManager.getConfig(__name__)
#     response = getRequest("users/")

#     if response:
#         username_list = response.json()
#         if config['username'] and config['username'] not in config['friends']:
#             config['friends'].append(config['username'])

#         if username in username_list and username not in config['friends']:
#             config['friends'].append(username)
#             write_config("friends", config['friends'])
#             tooltip(f"{username} is now your friend.")
#             self.dialog.friend_username.setText("")
#             self.updateFriendsList(sorted(config["friends"], key=str.lower))
#         else:
#             tooltip("Couldn't find friend")