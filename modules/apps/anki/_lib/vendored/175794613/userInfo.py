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



import json
from os.path import dirname, join, realpath


from aqt import mw
from aqt.utils import tooltip

from aqt.qt import qtmajor

try:
    from PyQt6.QtWidgets import QDialog, QMessageBox
    from PyQt6.QtGui import QIcon, QPixmap
    from PyQt6.QtCore import Qt, QUrl
except:
    from aqt.qt import QDialog, QMessageBox
    from aqt.qt import QIcon, QPixmap
    from aqt.qt import Qt, QUrl

# from aqt.qt import QDialog, Qt, QIcon, QPixmap, qtmajor

if qtmajor > 5:
    from .forms.pyqt6UI import user_info
    from PyQt6 import QtCore, QtWidgets
else:
    from .forms.pyqt5UI import user_info
    from PyQt5 import QtCore, QtWidgets

from .reportUser import start_report
from .config_manager import write_config
from .api_connect import postRequest
from .banUser import start_banUser

from .path_manager import ADDON_NAME

# Use leaderboard Plus
class start_user_info(QDialog):
    def __init__(self, user_clicked, enabled, parent=None):
        self.parent = parent
        self.user_clicked = user_clicked.split(" |")[0]
        self.enabled = enabled
        QDialog.__init__(self, parent, Qt.WindowType.Window)
        self.dialog = user_info.Ui_Dialog()
        self.dialog.setupUi(self)
        self.setupUI()

        config = mw.addonManager.getConfig(__name__)
        if config.get("allways_on_top", False):
            self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint)

    def setupUI(self):
        self.dialog.username_label.setText(self.user_clicked)

        icon = QIcon()
        icon.addPixmap(QPixmap(join(dirname(realpath(__file__)), "designer/icons/person.png")), QIcon.Mode.Normal, QIcon.State.Off)
        self.setWindowIcon(icon)

        if self.enabled == True:
            self.dialog.banUser.setEnabled(True)

        data = {"username": self.user_clicked}
        response = postRequest("getUserinfo/", data, 200)
        # country, groups, league, history, status

        if response:
            response = response.json()

            res_country = response[0]
            res_groups = response[1]
            res_league = response[2]
            res_history = response[3]
            res_status = response[4]


            if res_status:
                self.dialog.status_message.setMarkdown(res_status)
            else:
                pass

            if res_country== "Country":
                self.dialog.country_label.setText("")
            else:
                self.dialog.country_label.setText(f"Country: {res_country}")
            for i in res_groups:
                self.dialog.group_list.addItem(i)
            self.dialog.league_label.setText(f"League: {res_league}")


            header = self.dialog.history.horizontalHeader()
            header.setSectionResizeMode(0, QtWidgets.QHeaderView.ResizeMode.Stretch)
            header.setSectionResizeMode(1, QtWidgets.QHeaderView.ResizeMode.Stretch)
            header.setSectionResizeMode(2, QtWidgets.QHeaderView.ResizeMode.Stretch)
            header.setSectionResizeMode(3, QtWidgets.QHeaderView.ResizeMode.Stretch)
            if res_history:
                medals = ""
                history = json.loads(res_history)
                results = history["results"]
                if history["gold"] > 0:
                    medals = f"{medals} {history['gold'] if history['gold'] != 1 else ''}🥇"
                if history["silver"] > 0:
                    medals = f"{medals} {history['silver'] if history['silver'] != 1 else ''}🥈"
                if history["bronze"] > 0:
                    medals = f"{medals} {history['bronze'] if history['bronze'] != 1 else ''}🥉"
                self.dialog.medals_label.setText(f"Medals: {medals}")
                index = 0
                for i in results["leagues"]:
                    rowPosition = self.dialog.history.rowCount()
                    self.dialog.history.insertRow(rowPosition)

                    self.dialog.history.setItem(rowPosition , 3, QtWidgets.QTableWidgetItem(str(i)))

                    item = QtWidgets.QTableWidgetItem()
                    item.setData(QtCore.Qt.ItemDataRole.DisplayRole, int(results["seasons"][index]))
                    self.dialog.history.setItem(rowPosition, 0, item)
                    item.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignRight|QtCore.Qt.AlignmentFlag.AlignVCenter)

                    item = QtWidgets.QTableWidgetItem()
                    item.setData(QtCore.Qt.ItemDataRole.DisplayRole, int(results["xp"][index]))
                    self.dialog.history.setItem(rowPosition, 2, item)
                    item.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignRight|QtCore.Qt.AlignmentFlag.AlignVCenter)

                    item = QtWidgets.QTableWidgetItem()
                    item.setData(QtCore.Qt.ItemDataRole.DisplayRole, int(results["rank"][index]))
                    self.dialog.history.setItem(rowPosition, 1, item)
                    item.setTextAlignment(QtCore.Qt.AlignmentFlag.AlignRight|QtCore.Qt.AlignmentFlag.AlignVCenter)

                    index += 1

            self.dialog.hideUser.clicked.connect(self.hideUser)
            self.dialog.addFriend.clicked.connect(self.addFriend)
            self.dialog.banUser.clicked.connect(self.banUser)
            self.dialog.reportUser.clicked.connect(self.reportUser)
            self.dialog.history.sortItems(0, QtCore.Qt.SortOrder.DescendingOrder)

            self.setup_confirm_link()
            self.hide_user_message()


    #MARK: confirm_open_links
    def setup_confirm_link(self):
        self.dialog.status_message.setOpenExternalLinks(False)
        self.dialog.status_message.setOpenLinks(False)
        self.dialog.status_message.anchorClicked.connect(self.confirm_open_link)

    def confirm_open_link(self, url:"QUrl"):
        msg = QMessageBox(self)
        msg.setWindowTitle("Confirm open link")
        msg.setIcon(QMessageBox.Icon.Question)
        msg.setText(
            f"Open this external link?\n\n{url.toString()}\n\n"
            # f"I'm not responsible for the content so open at your own risk."
            "Make sure you trust the destination before continuing."
        )
        open_btn = msg.addButton("Open URL", QMessageBox.ButtonRole.AcceptRole)
        cancel_btn = msg.addButton("Cancel", QMessageBox.ButtonRole.RejectRole)
        msg.exec()
        if msg.clickedButton() == open_btn:
            from aqt.utils import openLink
            openLink(url)


    #MARK:Hide user message
    def hide_user_message(self):

        self.dialog.status_message.setMaximumHeight(0)

        self.dialog.label.setText("▶ User Biography (click to display)")
        self.dialog.label.setCursor(QtCore.Qt.CursorShape.PointingHandCursor)
        self.dialog.label.mousePressEvent = self.toggle_status_message

        from .config_local import get_local_config
        lo_config = get_local_config()
        if lo_config.get("is_show_user_bio", False):
            self.dialog.status_message.setMaximumHeight(2000)
            self.dialog.label.setText("▼ User Biography")


    def toggle_status_message(self, event=None):
        from .config_local import get_local_config, save_local_config
        lo_config = get_local_config()

        if self.dialog.status_message.maximumHeight() == 0:
            self.dialog.status_message.setMaximumHeight(2000)
            self.dialog.label.setText("▼ User Biography")
            lo_config["is_show_user_bio"] = True

        else:
            self.dialog.status_message.setMaximumHeight(0)
            self.dialog.label.setText("▶ User Biography (click to display)")
            lo_config["is_show_user_bio"] = False

        save_local_config(lo_config)


    def hideUser(self):
        config = mw.addonManager.getConfig(__name__)
        hidden = config["hidden_users"]
        hidden.append(self.user_clicked)
        write_config("hidden_users", hidden)
        tooltip(f"{self.user_clicked} will be hidden next time you open the leaderboard.")

    def addFriend(self):
        config = mw.addonManager.getConfig(__name__)
        friends = config['friends']
        if self.user_clicked in friends:
            tooltip(f"{self.user_clicked} already is your friend.")
        else:
            friends.append(self.user_clicked)
            write_config("friends", friends)
            tooltip(f"{self.user_clicked} is now your friend.")

    def banUser(self):
        s = start_banUser(self.user_clicked, self)
        if s.exec():
            pass

    def reportUser(self):
        s = start_report(self.user_clicked, self)
        if s.exec():
            pass
