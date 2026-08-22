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

from datetime import datetime
from os.path import dirname, join, realpath
import hashlib
import json

from aqt import QFileDialog, QHBoxLayout, QListWidgetItem, QPushButton, QSizePolicy, QVBoxLayout, QWidget, mw
from aqt.qt import QDialog, Qt, QIcon, QPixmap, qtmajor
from aqt.utils import tooltip, showInfo, showWarning, askUser, openLink

if qtmajor > 5:
    from .forms.pyqt6UI import config
    from PyQt6 import QtCore
else:
    from .forms.pyqt5UI import config
    from PyQt5 import QtCore
from .resetPassword import start_resetPassword
from .config_manager import write_config
from .version import version, about_text
from .api_connect import *
from .custom_shige.path_manager import PRIVACY_POLICY
from .shige_pop.popup_config import PATREON_URL, RATE_THIS_URL, change_log_popup_B
from .custom_shige.new_option_tab import NewOptionTab # add_new_option_tab
from .custom_shige.shige_addons import add_shige_addons_tab
from .custom_shige.about_wiki import add_about_wiki_tab
from .custom_shige.country_dict import COUNTRY_LIST

askUserCreateAccount = f"""
<h3>Sign-up</h3>
By signing up, you confirm that you read and accept the Privacy Policy of this add-on.
You can read it <a href="{PRIVACY_POLICY}">here</a>.
<br><br>
<b>Do you want to sign up now?</b>
"""

class start_config(QDialog):
    def __init__(self, season_start, season_end, parent=None):
        self.parent = parent
        self.season_start = season_start
        self.season_end = season_end
        QDialog.__init__(self, parent, Qt.WindowType.Window)
        self.dialog = config.Ui_Dialog()
        # self.dialog.setupUi(self) # ﾎﾞﾀﾝを追加しない場合に必要

        # 新しいｳｨｼﾞｪｯﾄを作成し､Ui_DialogのUIをその中に配置
        self.dialog_widget = QWidget()
        self.dialog.setupUi(self.dialog_widget)
        self.setWindowTitle("Leaderboard Config (Fixed by Shige)")
        self.dialog.newPwd.setPlaceholderText("necessary")
        self.dialog.oldPwd.setPlaceholderText("")

        self.setValues()
        self.connectSignals()
        self.loadGroup()
        self.loadStatus()
        self.accountAction()

        # index = self.dialog.tabWidget.indexOf(self.dialog.tabAbout)
        # if index != -1:
        #     self.dialog.tabWidget.removeTab(index)
        self.new_option_tab_instance = NewOptionTab(self.dialog.tabWidget, self.dialog_widget)

        # add_new_option_tab(self.dialog_widget, self.dialog.tabWidget)
        # add_about_wiki_tab(self.dialog_widget, self.dialog.tabWidget)
        add_shige_addons_tab(self.dialog_widget, self.dialog.tabWidget)



        self.wiki_button = QPushButton("📖Wiki")
        self.wiki_button.setStyleSheet("QPushButton { padding: 2px; }")
        self.wiki_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        self.wiki_button.clicked.connect(lambda: openLink(
            "https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html"))

        self.rate_button = QPushButton("👍️RateThis")
        self.rate_button.setStyleSheet("QPushButton { padding: 2px; }")
        self.rate_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        self.rate_button.clicked.connect(lambda: openLink(RATE_THIS_URL))
        if RATE_THIS_URL == "":
            self.rate_button.setEnabled(False)

        self.patreon_button = QPushButton("💖Become a Patron")
        self.patreon_button.setStyleSheet("QPushButton { padding: 2px; }")
        self.patreon_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        self.patreon_button.clicked.connect(lambda: openLink(PATREON_URL))

        self.help_button = QPushButton("📋Log")
        self.help_button.setStyleSheet("QPushButton { padding: 2px; }")
        self.help_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        self.help_button.clicked.connect(change_log_popup_B)

        self.report_button = QPushButton("🚨Report")
        self.report_button.setStyleSheet("QPushButton { padding: 2px; }")
        self.report_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        self.report_button.clicked.connect(lambda: openLink(
            "https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html#report-problems-or-requests"
        ))


        # ﾎﾞﾀﾝを水平に配置
        self.hbox = QHBoxLayout()
        self.hbox.addStretch(1)
        self.hbox.addWidget(self.wiki_button)
        self.hbox.addWidget(self.rate_button)
        self.hbox.addWidget(self.patreon_button)
        self.hbox.addWidget(self.help_button)
        self.hbox.addWidget(self.report_button)

        # 新しいﾚｲｱｳﾄを作成し､既存のｳｨｼﾞｪｯﾄと新しいﾎﾞﾀﾝを追加
        self.vbox = QVBoxLayout()
        self.vbox.addWidget(self.dialog_widget)
        self.vbox.addLayout(self.hbox)

        # 新しいﾚｲｱｳﾄをこのｳｨｼﾞｪｯﾄに設定
        self.setLayout(self.vbox)

        self.hide_hiddenlist() # Enhance Hidden

        # Enhance Friends ----
        self.add_search_users_button()
        self.dialog.friends_list.itemDoubleClicked.connect(self.on_item_double_clicked)
        self.dialog.add_friends_button.setVisible(False)
        self.dialog.friend_username.setVisible(False)
        self.add_friend_user_info_button()


    # Enhance Friends ------
    def on_item_double_clicked(self, item: QListWidgetItem):
        if item is not None:
            user_clicked = item.text()
            if user_clicked:
                from .userInfo import start_user_info
                self.shige_user_info = start_user_info(user_clicked, False)
                self.shige_user_info.show()
                self.shige_user_info.raise_()
                self.shige_user_info.activateWindow()

    def run_serach_users_window(self):
        from .config_search_friends import SearchFriendWindow
        search_window = SearchFriendWindow(self)
        search_window.exec()

    def add_search_users_button(self):
        self.new_button = QPushButton(self.dialog.tabFriends)
        self.new_button.setAutoDefault(False)
        self.new_button.setObjectName("Search Users")
        self.new_button.setText("Search Users")
        self.new_button.clicked.connect(self.run_serach_users_window)

        # add_friends_button の位置を取得
        add_friends_button_index = self.dialog.gl4.indexOf(self.dialog.add_friends_button)
        add_friends_button_pos = self.dialog.gl4.getItemPosition(add_friends_button_index)
        # 新しいﾎﾞﾀﾝを add_friends_button の上に追加
        self.dialog.gl4.addWidget(self.new_button, add_friends_button_pos[0] - 1, add_friends_button_pos[1], 1, 1)


    def add_friend_user_info_button(self):
        self.user_info = QPushButton(self.dialog.tabFriends)
        self.user_info.setAutoDefault(False)
        self.user_info.setObjectName("User Info")
        self.user_info.setText("User Info")
        self.user_info.clicked.connect(self.frienduserInfo)
        self.dialog.vl1.insertWidget(3, self.user_info)



    def frienduserInfo(self):
        for item in self.dialog.friends_list.selectedItems():
            username = item.text()
            if username:
                from .userInfo import start_user_info
                self.shige_user_info = start_user_info(username, False)
                self.shige_user_info.show()
                self.shige_user_info.raise_()
                self.shige_user_info.activateWindow()


    #  ------------------------


    # General

    def connectSignals(self):
        self.dialog.account_button.clicked.connect(self.accountButton)
        self.dialog.account_forgot.clicked.connect(self.accountForgot)
        self.dialog.account_action.currentIndexChanged.connect(self.accountAction)
        self.dialog.account_mail.textChanged.connect(self.checkLineEdit)
        self.dialog.account_username.textChanged.connect(self.checkLineEdit)
        self.dialog.account_new_username.textChanged.connect(self.checkLineEdit)
        self.dialog.account_pwd.textChanged.connect(self.checkLineEdit)
        self.dialog.account_pwd_repeat.textChanged.connect(self.checkLineEdit)
        self.dialog.statusButton.clicked.connect(self.status)
        self.dialog.friend_username.returnPressed.connect(self.addFriend)
        self.dialog.add_friends_button.clicked.connect(self.addFriend)
        self.dialog.remove_friend_button.clicked.connect(self.removeFriend)
        self.dialog.newday.valueChanged.connect(self.setTime)
        self.dialog.joinGroup.clicked.connect(self.joinGroup)
        self.dialog.leaveGroup.clicked.connect(self.leaveGroup)
        self.dialog.add_newGroup.clicked.connect(self.createNewGroup)
        self.dialog.manageSave.clicked.connect(self.manageGroup)
        self.dialog.country.currentTextChanged.connect(self.setCountry)
        self.dialog.Default_Tab.currentTextChanged.connect(self.setDefaultTab)
        self.dialog.sortby.currentTextChanged.connect(self.setSortby)
        self.dialog.scroll.stateChanged.connect(self.setScroll)
        self.dialog.medals.stateChanged.connect(self.setMedals)
        self.dialog.import_friends.clicked.connect(self.importList)
        self.dialog.export_friends.clicked.connect(self.exportList)
        self.dialog.unhideButton.clicked.connect(self.unhide)
        self.dialog.LB_DeckBrowser.stateChanged.connect(self.setHomescreen)
        self.dialog.autosync.stateChanged.connect(self.setAutosync)
        self.dialog.maxUsers.valueChanged.connect(self.setMaxUser)
        self.dialog.lb_focus.stateChanged.connect(self.setFocus)

    def setValues(self):
        _translate = QtCore.QCoreApplication.translate
        config = mw.addonManager.getConfig(__name__)

        icon = QIcon()
        icon.addPixmap(QPixmap(join(dirname(realpath(__file__)), "designer/icons/settings.png")), QIcon.Mode.Normal, QIcon.State.Off)
        self.setWindowIcon(icon)

        self.updateLoginInfo(config["username"])
        self.dialog.account_forgot.hide()
        self.dialog.newday.setValue(int(config['newday']))
        self.dialog.Default_Tab.setCurrentIndex(config['tab'])
        self.dialog.scroll.setChecked(bool(config["scroll"]))
        self.updateFriendsList(sorted(config["friends"], key=str.lower))
        self.updateHiddenList(sorted(config["hidden_users"], key=str.lower))
        self.updateGroupList(sorted(config["groups"], key=str.lower))
        self.dialog.LB_DeckBrowser.setChecked(bool(config["homescreen"]))
        self.dialog.autosync.setChecked(bool(config["autosync"]))
        self.dialog.maxUsers.setValue(config["maxUsers"])
        self.dialog.lb_focus.setChecked(bool(config["focus_on_user"]))
        self.dialog.medals.setChecked(bool(config["show_medals"]))
        self.dialog.about_text.setHtml(about_text)
        if config["sortby"] == "Time_Spend":
            self.dialog.sortby.setCurrentText("Time")
        if config["sortby"] == "Month":
            self.dialog.sortby.setCurrentText("Reviews past 30 days")
        else:
            self.dialog.sortby.setCurrentText(config["sortby"])

        self.dialog.Default_Tab.setToolTip("This affects the Leaderboard and, if enabled, the home screen leaderboard.")
        self.dialog.sortby.setToolTip("This affects the Leaderboard and, if enabled, the home screen leaderboard.")
        self.dialog.newday.setToolTip("This needs to be the same as in Ankis' preferences.")
        self.dialog.autosync.setToolTip("It will take a few extra seconds before you return to the homescreen after answering the last due card in a deck.")

        for i in range(1, 256):
            self.dialog.country.addItem("")
        # item 0 is set by pyuic from the .ui file
        for i in COUNTRY_LIST:
            self.dialog.country.setItemText(COUNTRY_LIST.index(i), _translate("Dialog", i))

        self.dialog.country.setCurrentText(config["country"])

        if not config["authToken"]:
            self.dialog.tabWidget.setTabEnabled(2, False)

    def accountAction(self):
        self.dialog.account_mail.setText("")
        self.dialog.account_username.setText("")
        self.dialog.account_new_username.setText("")
        self.dialog.account_pwd.setText("")
        self.dialog.account_pwd_repeat.setText("")
        index = self.dialog.account_action.currentIndex()
        self.checkLineEdit()
        if index == 0:
            self.dialog.account_button.setText("Sign up")
            self.dialog.account_mail.show()
            self.dialog.account_username.show()
            self.dialog.account_new_username.hide()
            self.dialog.account_pwd.show()
            self.dialog.account_pwd_repeat.show()
            self.dialog.account_forgot.hide()
            self.dialog.account_username.setPlaceholderText("Username")
            self.dialog.account_button.setEnabled(False)
        if index == 1:
            self.dialog.account_button.setText("Log in")
            self.dialog.account_mail.hide()
            self.dialog.account_username.show()
            self.dialog.account_new_username.hide()
            self.dialog.account_pwd.show()
            self.dialog.account_pwd_repeat.hide()
            self.dialog.account_forgot.show()
            self.dialog.account_username.setPlaceholderText("Username")
            self.dialog.account_button.setEnabled(False)
        if index == 2:
            self.dialog.account_button.setText("Delete Account")
            self.dialog.account_mail.hide()
            self.dialog.account_username.show()
            self.dialog.account_new_username.hide()
            self.dialog.account_pwd.show()
            self.dialog.account_pwd_repeat.hide()
            self.dialog.account_forgot.show()
            self.dialog.account_username.setPlaceholderText("Username")
            self.dialog.account_button.setEnabled(False)
        if index == 3:
            self.dialog.account_button.setText("Log out")
            self.dialog.account_mail.hide()
            self.dialog.account_username.hide()
            self.dialog.account_new_username.hide()
            self.dialog.account_pwd.hide()
            self.dialog.account_pwd_repeat.hide()
            self.dialog.account_forgot.hide()
            self.dialog.account_button.setEnabled(True)
        if index == 4:
            self.dialog.account_button.setText("Change username")
            self.dialog.account_mail.hide()
            self.dialog.account_username.show()
            self.dialog.account_new_username.show()
            self.dialog.account_pwd.show()
            self.dialog.account_pwd_repeat.hide()
            self.dialog.account_forgot.show()
            self.dialog.account_username.setPlaceholderText("Username")
            self.dialog.account_button.setEnabled(False)

    def accountButton(self):
        index = self.dialog.account_action.currentIndex()
        if index == 0:
            self.signUp()
        if index == 1:
            self.logIn()
        if index == 2:
            self.deleteAccount()
        if index == 3:
            self.logOut()
        if index == 4:
            self.changeUsername()

    def checkLineEdit(self):
        email = self.dialog.account_mail.text()
        username = self.dialog.account_username.text()
        new_username = self.dialog.account_new_username.text()
        pwd = self.dialog.account_pwd.text()
        pwd_repeat = self.dialog.account_pwd_repeat.text()
        index = self.dialog.account_action.currentIndex()
        if index == 0 or index == 3:
            if email and username and pwd and pwd_repeat:
                if pwd == pwd_repeat:
                    self.dialog.account_button.setEnabled(True)
                    self.dialog.account_pwd_repeat.setStyleSheet("background-color: var(--window-bg)")
                if pwd != pwd_repeat:
                    self.dialog.account_button.setEnabled(False)
                    self.dialog.account_pwd_repeat.setStyleSheet("background-color: #ff4242")
            else:
                self.dialog.account_button.setEnabled(False)
        if index == 5:
            if username and pwd and new_username:
                self.dialog.account_button.setEnabled(True)
            else:
                self.dialog.account_button.setEnabled(False)
        if index == 1 or index == 2 or index == 4:
            if username and pwd:
                self.dialog.account_button.setEnabled(True)
            else:
                self.dialog.account_button.setEnabled(False)

    def updateLoginInfo(self, username):
        login_info = self.dialog.login_info_2
        if username:
            login_info.setText(f"Logged in as {username}.")
        else:
            login_info.setText("You are not logged in.")

    def updateFriendsList(self, friends):
        config = mw.addonManager.getConfig(__name__)
        friends_list = self.dialog.friends_list
        friends_list.clear()
        for friend in friends:
            if friend != config['username']:
                friends_list.addItem(friend)

    def updateGroupList(self, groups):
        group_list = self.dialog.group_list
        group_list.clear()
        for group in groups:
            group_list.addItem(group)

    # Account/API calls

    def signUp(self):
        email = self.dialog.account_mail.text()
        username = self.dialog.account_username.text()
        pwd = self.dialog.account_pwd.text()

        if askUser(askUserCreateAccount):
            data = {"email": email, "username": username, "pwd": pwd, "syncDate": datetime.now(), "version": version}
            response = postRequest("signUp/", data, 201)
            if response:
                write_config("authToken", response.json())
                write_config("username", username)
                self.updateLoginInfo(username)
                tooltip("Successfully signed-up")
                self.dialog.tabWidget.setTabEnabled(2, True)
        else:
            pass

    def logIn(self):
        username = self.dialog.account_username.text()
        pwd = self.dialog.account_pwd.text()
        data = {"username": username, "pwd": pwd}
        
        response = postRequest("logIn/", data, 200)
        if response:
            write_config("authToken", response.json())
            write_config("username", username)
            self.updateLoginInfo(username)
            tooltip("Successfully logged-in")
            self.dialog.tabWidget.setTabEnabled(2, True)

    def deleteAccount(self):
        config = mw.addonManager.getConfig(__name__)
        username = self.dialog.account_username.text()
        pwd = self.dialog.account_pwd.text()
        if askUser("<h3>Deleting Account</h3>If you delete your account, all your data will be deleted. <br><br><b>Do you want to delete your account now?</b>"):
            data = {"username": username, "pwd": pwd}
            response = postRequest("deleteAccount/", data, 204)
            if response:
                write_config("authToken", None)
                write_config("username", "")
                self.updateLoginInfo("")
                tooltip("Successfully deleted account")
                self.dialog.tabWidget.setTabEnabled(2, False)

    def changeUsername(self):
        username = self.dialog.account_username.text()
        newUsername = self.dialog.account_new_username.text()
        pwd = self.dialog.account_pwd.text()

        if askUser("If someone added you as a friend, they will have to re-add you after you changed your username.<br><br><b>Do you want to proceed?</b>"):
            data = {"username": username,"newUsername": newUsername,"pwd": pwd}
            response = postRequest("changeUsername/", data, 200)
            if response:
                write_config("authToken", response.json())
                write_config("username", newUsername)
                self.updateLoginInfo(newUsername)
                tooltip("Successfully updated account")
        else:
            pass

    def logOut(self):
        write_config("authToken", None)
        write_config("username", "")
        self.updateLoginInfo("")
        tooltip("Successfully logged-out")
        self.dialog.tabWidget.setTabEnabled(2, False)

    def accountForgot(self):
        s = start_resetPassword()
        if s.exec():
            pass

    def loadGroup(self):
        config = mw.addonManager.getConfig(__name__)
        _translate = QtCore.QCoreApplication.translate
        groupList = getRequest("groups/")

        if groupList:
            # item 0 is set by pyuic from the .ui file
            for i in range(1, len(groupList.json()) + 1):
                self.dialog.subject.addItem("")
                self.dialog.manageGroup.addItem("")

            index = 1
            for i in groupList.json():
                self.dialog.subject.setItemText(index, _translate("Dialog", i))
                self.dialog.manageGroup.setItemText(index, _translate("Dialog", i))
                index += 1
            self.dialog.subject.setCurrentText(config["current_group"])

    def joinGroup(self):
        group = self.dialog.subject.currentText()
        config = mw.addonManager.getConfig(__name__)
        groupList = config["groups"]
        if group == "Join a group":
            return
        pwd = self.dialog.joinPwd.text()
        if pwd:
            pwd = hashlib.sha1(pwd.encode('utf-8')).hexdigest().upper()
        else:
            pwd = None

        data = {"username": config["username"], "group": group, "pwd": pwd, "authToken": config["authToken"]}
        response = postRequest("joinGroup/", data, 200)
        if response:
            if not config["current_group"]:
                write_config("current_group", group)
            if group not in groupList:
                groupList.append(group)
                write_config("groups", groupList)
                self.updateGroupList(sorted(groupList, key=str.lower))
                tooltip(f"You joined {group}")
            self.dialog.joinPwd.clear()

    def leaveGroup(self):
        config = mw.addonManager.getConfig(__name__)
        for item in self.dialog.group_list.selectedItems():
            group = item.text()
            data = {"username": config["username"], "group": group, "authToken": config["authToken"]}
            response = postRequest("leaveGroup/", data, 200)
            if response:
                config['groups'].remove(group)
                write_config("groups", config["groups"])
                if len(config['groups']) > 0:
                    write_config("current_group", config["groups"][0])
                else:
                    write_config("current_group", None)
                self.updateGroupList(sorted(config["groups"], key=str.lower))
                tooltip(f"You left {group}.")

    def createNewGroup(self):
        config = mw.addonManager.getConfig(__name__)
        groupName = self.dialog.newGroup.text()
        pwd = self.dialog.newPwd.text()
        rpwd = self.dialog.newRepeat.text()

        if pwd != rpwd:
            showWarning("Passwords are not the same.")
            self.dialog.newPwd.clear()
            self.dialog.newRepeat.clear()
            return
        else:
            if pwd != "":
                pwd = hashlib.sha1(pwd.encode('utf-8')).hexdigest().upper()
            else:
                pwd = None

        data = {'groupName': groupName, "username": config['username'], "pwd": pwd}
        response = postRequest("createGroup/", data, 200)
        if response:
            tooltip("Successfully created group. Re-open config.")
            self.dialog.newGroup.setText("")
            self.dialog.newPwd.setText("")
            self.dialog.newRepeat.setText("")

    def manageGroup(self):
        config = mw.addonManager.getConfig(__name__)
        group = self.dialog.manageGroup.currentText()
        oldPwd = self.dialog.oldPwd.text()
        newPwd = self.dialog.manage_newPwd.text()
        rPwd = self.dialog.manage_newRepeat.text()
        addAdmin = self.dialog.newAdmin.text()

        if newPwd != rPwd:
            showWarning("Passwords are not the same.")
            self.dialog.manage_newPwd.clear()
            self.dialog.manage_newRepeat.clear()
            return
        else:
            if oldPwd == "":
                oldPwd = None
            else:
                oldPwd = hashlib.sha1(oldPwd.encode('utf-8')).hexdigest().upper()

            if newPwd == "":
                newPwd = oldPwd
            else:
                newPwd = hashlib.sha1(newPwd.encode('utf-8')).hexdigest().upper()

        data = {'group': group, "username": config["username"], "authToken": config["authToken"], "oldPwd": oldPwd, "newPwd": newPwd, "addAdmin": addAdmin}
        response = postRequest("manageGroup/", data, 200)
        if response:
            tooltip(f"{group} was updated successfully.")
            self.dialog.oldPwd.setText("")
            self.dialog.manage_newPwd.setText("")
            self.dialog.manage_newRepeat.setText("")
            self.dialog.newAdmin.setText("")

    def status(self):
        config = mw.addonManager.getConfig(__name__)
        statusMsg = self.dialog.statusMsg.toPlainText()
        if len(statusMsg) > 280:
            showWarning("The message can only be 280 characters long.", title="Leaderboard")
            return
        data = {"status": statusMsg, "username": config["username"], "authToken": config["authToken"]}
        response = postRequest("setBio/", data, 200)
        if response:
            tooltip("Done")

    def loadStatus(self):
        config = mw.addonManager.getConfig(__name__)
        if config["username"]:
            response = postRequest("getBio/", {"username": config["username"]}, 200)
            if response:
                self.dialog.statusMsg.setText(response.json())

    # Change settings

    def addFriend(self):
        username = self.dialog.friend_username.text()
        config = mw.addonManager.getConfig(__name__)
        response = getRequest("users/")

        if response:
            username_list = response.json()
            if config['username'] and config['username'] not in config['friends']:
                config['friends'].append(config['username'])

            if username in username_list and username not in config['friends']:
                config['friends'].append(username)
                write_config("friends", config['friends'])
                tooltip(f"{username} is now your friend.")
                self.dialog.friend_username.setText("")
                self.updateFriendsList(sorted(config["friends"], key=str.lower))
            else:
                tooltip("Couldn't find friend")

    def removeFriend(self):
        for item in self.dialog.friends_list.selectedItems():
            username = item.text()
            config = mw.addonManager.getConfig(__name__)
            config['friends'].remove(username)
            write_config("friends", config["friends"])
            tooltip(f"{username} was removed from your friendlist")
            self.updateFriendsList(sorted(config["friends"], key=str.lower))

    def setTime(self):
        beginning_of_new_day = self.dialog.newday.value()
        write_config("newday", beginning_of_new_day)

    def setCountry(self):
        country = self.dialog.country.currentText()
        if country not in COUNTRY_LIST:
            country = "Country"
        write_config("country", country)

    def setScroll(self):
        if self.dialog.scroll.isChecked():
            scroll = True
        else:
            scroll = False
        write_config("scroll", scroll)

    def setDefaultTab(self):
        config = mw.addonManager.getConfig(__name__)
        tab = self.dialog.Default_Tab.currentText()
        if tab == "Global":
            write_config("tab", 0)
        if tab == "Friends":
            write_config("tab", 1)
        if tab == "Country":
            write_config("tab", 2)
        if tab == "Group":
            write_config("tab", 3)
        if tab == "League":
            write_config("tab", 4)
        if config["homescreen"] == True:
            write_config("homescreen_data", [])
            tooltip("Changes will apply after the next sync")

    def setSortby(self):
        config = mw.addonManager.getConfig(__name__)
        sortby = self.dialog.sortby.currentText()
        if sortby == "Reviews":
            write_config("sortby", "Cards")
        if sortby == "Time":
            write_config("sortby", "Time_Spend")
        if sortby == "Streak":
            write_config("sortby", sortby)
        if sortby == "Reviews past 31 days":
            write_config("sortby", "Month")
        if sortby == "Retention":
            write_config("sortby", sortby)
        if config["homescreen"] == True:
            write_config("homescreen_data", [])
            tooltip("Changes will apply after the next sync")

    def setHomescreen(self):
        config = mw.addonManager.getConfig(__name__)
        if self.dialog.LB_DeckBrowser.isChecked():
            homescreen = True
        else:
            homescreen = False
        write_config("homescreen", homescreen)
        tooltip("Changes will apply after the next sync")

    def setMaxUser(self):
        config = mw.addonManager.getConfig(__name__)
        maxUsers = self.dialog.maxUsers.value()
        write_config("maxUsers", maxUsers)
        if config["homescreen"] == True:
            tooltip("Changes will apply after the next sync")

    def setAutosync(self):
        if self.dialog.autosync.isChecked():
            autosync = True
        else:
            autosync = False
        write_config("autosync", autosync)

    def setFocus(self):
        config = mw.addonManager.getConfig(__name__)
        if self.dialog.lb_focus.isChecked():
            focus = True
        else:
            focus = False
        write_config("focus_on_user", focus)
        if config["homescreen"] == True:
            tooltip("Changes will apply after the next sync")

    def setMedals(self):
        config = mw.addonManager.getConfig(__name__)
        if self.dialog.medals.isChecked():
            medals = True
        else:
            medals = False
        write_config("show_medals", medals)
        if config["homescreen"] == True:
            write_config("homescreen_data", [])
            tooltip("Changes will apply after the next sync")

    def importList(self):
        # showInfo("The text file must contain one name per line.")
        tooltip("The text file must contain one name per line.")
        config = mw.addonManager.getConfig(__name__)

        default_path = join(dirname(realpath(__file__)), "Friends.txt")
        fname = QFileDialog.getOpenFileName(None, 'Open file', default_path,"Text files (*.txt)")
        
        # fname = QFileDialog.getOpenFileName(self, 'Open file', "C:\\","Text files (*.txt)")

        if not fname:
            tooltip("Please pick a text file to import friends.")
            return

        try:
            file = open(fname[0], "r", encoding= "utf-8")
            friends_list = config["friends"]
            response = getRequest("users/")

            if response:
                # response = response.json()
                username_list = response.json()
                for name in file:
                    name = name.replace("\n", "")
                    if name in username_list and name not in config["friends"]:
                        friends_list.append(name)

                if config["username"] and config["username"] not in friends_list:
                    friends_list.append(config["username"])

                self.updateFriendsList(sorted(friends_list, key=str.lower))
                write_config("friends", friends_list)
        except:
            tooltip(f"Hmmm, an error occurred while importing :-/")
            # showInfo("Please pick a text file to import friends.")

    # def exportList(self):
    #     config = mw.addonManager.getConfig(__name__)
    #     friends_list = config["friends"]
    #     export_file = open(join(dirname(realpath(__file__)), "Friends.txt"), "w", encoding="utf-8") 
    #     for i in friends_list:
    #         export_file.write(i+"\n")
    #     export_file.close()
    #     tooltip("You can find the text file in the add-on folder.")

    def exportList(self):
        config = mw.addonManager.getConfig(__name__)
        friends_list = config["friends"]

        default_path = join(dirname(realpath(__file__)), "Friends.txt")
        file_path, _ = QFileDialog.getSaveFileName(None, "Save Friends List", default_path, "Text Files (*.txt);;All Files (*)")

        if file_path:
            try:
                with open(file_path, "w", encoding="utf-8") as export_file:
                    for i in friends_list:
                        export_file.write(i + "\n")
                tooltip("Successfully exported! :-)")
            except Exception as e:
                tooltip(f"Hmmm, an error occurred while exporting :-/")
        else:
            tooltip("Hmmm, the export was cancelled :-/")


    def updateHiddenList(self, hidden):
        config = mw.addonManager.getConfig(__name__)
        hiddenUsers = self.dialog.hiddenUsers
        hiddenUsers.clear()
        for user in hidden:
            hiddenUsers.addItem(user)

    def unhide(self):
        for item in self.dialog.hiddenUsers.selectedItems():
            username = item.text()
            config = mw.addonManager.getConfig(__name__)
            config['hidden_users'].remove(username)
            write_config("hidden_users", config["hidden_users"])
            tooltip(f"{username} is now back on the leaderboard")
            self.updateHiddenList(config["hidden_users"])


    def hide_hiddenlist(self):
        for index in range(self.dialog.hiddenUsers.count()):
            item = self.dialog.hiddenUsers.item(index)
            item.setData(1000, item.text())
            original_text = item.text()
            masked_text = '*' * len(original_text)
            item.setText(masked_text)

        self.dialog.hiddenUsers.itemSelectionChanged.connect(self.show_original_text)

    def show_original_text(self):
        selected_items = self.dialog.hiddenUsers.selectedItems()
        for item in selected_items:
            original_text = item.data(1000)
            item.setText(original_text)