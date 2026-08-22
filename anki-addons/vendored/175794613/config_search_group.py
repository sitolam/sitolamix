# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import hashlib

from aqt import QHBoxLayout, QSizePolicy, mw, QDialog, QVBoxLayout, QPushButton, QLabel, QLineEdit
from aqt.utils import openLink, tooltip
from aqt.operations import QueryOp
from anki.utils import pointVersion

from .api_connect import getRequest, postRequest
from .config_manager import write_config
from .custom_shige.searchable_combobox import SearchableComboBox

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from config import start_config


WINDOW_NAME = "Search Group"


class SearchGroupWindow(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.start_config = parent # type: start_config
        if parent == None:
            return
        self.list_groups = None

        self.setWindowTitle(WINDOW_NAME)
        self.setGeometry(100, 100, 300, 100)

        self.vbox_layout = QVBoxLayout()

        self.search_input = SearchableComboBox(self)
        self.vbox_layout.addWidget(self.search_input)

        self.password_input = QLineEdit(self)
        self.password_input.setPlaceholderText("Password")
        self.password_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.vbox_layout.addWidget(self.password_input)

        self.result_label = QLabel(self)
        self.result_label.setText("Now loading...")
        self.vbox_layout.addWidget(self.result_label)

        hbox = QHBoxLayout()

        self.join_button = QPushButton("Join Group", self)
        self.join_button.clicked.connect(self.joinGroup)
        self.join_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        self.join_button.setStyleSheet("QPushButton { padding: 2px; }")
        hbox.addWidget(self.join_button)

        self.leave_button = QPushButton("leave Group", self)
        self.leave_button.clicked.connect(self.leaveGroup)
        self.leave_button.setStyleSheet("QPushButton { padding: 2px; }")
        self.leave_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        hbox.addWidget(self.leave_button)


        self.wiki_button = QPushButton("📖Wiki")
        self.wiki_button.setStyleSheet("QPushButton { padding: 2px; }")
        self.wiki_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        self.wiki_button.clicked.connect(lambda: openLink(
            "https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html#group"))
        hbox.addWidget(self.wiki_button)


        self.vbox_layout.addLayout(hbox)

        self.setLayout(self.vbox_layout)

        self.get_group_list()
        self.center()

    def center(self):
        if self.parent():
            parent_rect = self.start_config.geometry()
            self_rect = self.geometry()
            x = parent_rect.x() + (parent_rect.width() - self_rect.width()) // 2
            y = parent_rect.y() + (parent_rect.height() - self_rect.height()) // 2
            self.move(x, y)

    def get_group_list(self):
        op = QueryOp(
            parent=self,
            op=self.load_group,
            success=self.additems_groups
        )
        if pointVersion() >= 231000:
            op.without_collection()
        op.run_in_background()


    def load_group(self, col):
        response = getRequest("groups/", False)
        if response:
            groupList = response.json()

            self.list_groups = []
            for group in groupList:
                self.list_groups.append(group)


    def additems_groups(self, result):
        if self.list_groups:
            self.search_input.addItems(self.list_groups)
            self.result_label.setText("Please enter the group name and password.")
            self.search_input.setCurrentText("")
        else:
            self.result_label.setText("Hmmm, loading failed :-(")
            self.search_input.setCurrentText("")


    def joinGroup(self):
        group_name = self.search_input.currentText()
        password = self.password_input.text()

        if not group_name or not password:
            tooltip("Please enter the group name and password😭")
            return

        config = mw.addonManager.getConfig(__name__)
        groupList = config["groups"] # type: list


        if password:
            password = hashlib.sha1(password.encode('utf-8')).hexdigest().upper()
        else:
            password = None

        data = {"username": config["username"],
                "group": group_name,
                "pwd": password,
                "authToken": config["authToken"]
                }

        response = postRequest("joinGroup/", data, 200)
        if response:
            # if not config["current_group"]:
            write_config("current_group", group_name)
            if group_name not in groupList:
                groupList.append(group_name)
                write_config("groups", groupList)
                self.result_label.setText(f"You joined {group_name}! :-)")
            self.password_input.clear()


    def leaveGroup(self):

        config = mw.addonManager.getConfig(__name__)

        group_name = self.search_input.currentText()
        if not group_name:
            tooltip("Please enter the group name😭")
            return

        data = {"username": config["username"],
                "group": group_name,
                "authToken": config["authToken"]
                }

        response = postRequest("leaveGroup/", data, 200)
        if response:
            if group_name in config['groups']:
                config['groups'].remove(group_name)
                write_config("groups", config["groups"])
            if len(config['groups']) > 0:
                write_config("current_group", config["groups"][0])
            else:
                write_config("current_group", None)
            self.result_label.setText(f"You left {group_name}! :-)")