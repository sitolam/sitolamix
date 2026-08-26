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

from aqt.qt import QDialog, Qt, QIcon, QPixmap, qtmajor
from aqt.utils import tooltip
from aqt import mw
import hashlib
from os.path import dirname, join, realpath

if qtmajor > 5:
    from .forms.pyqt6UI import banUser
else:
    from .forms.pyqt5UI import banUser
from .api_connect import postRequest


class start_banUser(QDialog):
    def __init__(self, user_clicked, parent=None):
        self.parent = parent
        QDialog.__init__(self, parent, Qt.WindowType.Window)
        self.dialog = banUser.Ui_Dialog()
        self.dialog.setupUi(self)
        self.user_clicked = user_clicked
        self.setupUI()

    def setupUI(self):
        self.dialog.banButton.clicked.connect(self.banUser)

        icon = QIcon()
        icon.addPixmap(QPixmap(join(dirname(realpath(__file__)), "designer/icons/person.png")), QIcon.Mode.Normal, QIcon.State.Off)
        self.setWindowIcon(icon)

    def banUser(self):
        config = mw.addonManager.getConfig(__name__)
        password = hashlib.sha1(self.dialog.groupPassword.text().encode('utf-8')).hexdigest().upper()
        toBan = self.user_clicked
        data = {"toBan": toBan, "group": config["current_group"], "pwd": password, "authToken": config["authToken"], "username": config["username"]}
        response = postRequest("banUser/", data, 200)
        if response:
            tooltip(f"{toBan} is now banned from {config['current_group']}")

