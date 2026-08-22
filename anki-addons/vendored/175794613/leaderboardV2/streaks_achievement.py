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

from os.path import dirname, join, realpath

from aqt import mw, QFont, QLabel, QRect
from aqt.qt import QMovie, QDialog, Qt, QIcon, QPixmap, QCoreApplication, QMetaObject

from ..config_manager import write_config
from ..custom_shige.translate.translate import ShigeTranslator
QCoreApplication.translate = ShigeTranslator.translate


class Ui_Dialog(object):
    def setupUi(self, Dialog: QDialog):
        Dialog.setObjectName("Dialog")
        Dialog.resize(358, 279)
        Dialog.setAutoFillBackground(False)
        Dialog.setStyleSheet("")
        self.confetti = QLabel(Dialog)
        self.confetti.setGeometry(QRect(9, 9, 341, 261))
        self.confetti.setAutoFillBackground(False)
        self.confetti.setStyleSheet("QLabel{background:lightblue}")
        self.confetti.setText("")
        self.confetti.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.confetti.setObjectName("confetti")
        self.message = QLabel(Dialog)
        self.message.setGeometry(QRect(80, 120, 187, 40))
        font = QFont()
        font.setFamily("Bahnschrift")
        font.setPointSize(20)
        self.message.setFont(font)
        self.message.setText("")
        self.message.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.message.setObjectName("message")

        self.retranslateUi(Dialog)
        QMetaObject.connectSlotsByName(Dialog)

    def retranslateUi(self, Dialog: QDialog):
        _translate = QCoreApplication.translate
        Dialog.setWindowTitle(_translate("Dialog", "Leaderboard"))


class start_achievement(QDialog):
    def __init__(self, value, parent=None):
        self.parent = parent
        QDialog.__init__(self, parent, Qt.WindowType.Window)
        self.dialog = Ui_Dialog()
        self.dialog.setupUi(self)
        self.value = value
        self.setupUI()

    def setupUI(self):
        self.gif = QMovie(join(dirname(dirname(realpath(__file__))), 'designer/gifs/confetti.gif'))
        self.dialog.confetti.setMovie(self.gif)
        self.gif.start()

        icon = QIcon()
        icon.addPixmap(QPixmap(join(dirname(dirname(realpath(__file__))), "designer/icons/krone.png")), QIcon.Mode.Normal, QIcon.State.Off)
        self.setWindowIcon(icon)

        self.dialog.message.setGeometry(QRect(0, 0, 358, 279))
        self.dialog.message.setAlignment(Qt.AlignmentFlag.AlignCenter)

        if isinstance(self.value, int) and self.value % 365 == 0:
            years = self.value // 365
            year_text = "year" if years == 1 else "years"
            self.dialog.message.setText(f"{self.value} day streak!<br>That's {years} {year_text}!")
        else:
            self.dialog.message.setText(f"{self.value} day streak!")


def achievement(self, streak):
    config = mw.addonManager.getConfig(__name__)
    def is_repeating_number(n):
        s = str(n)
        if len(s) >= 3:
            return all(c == s[0] for c in s)
        return False

    if (config["achievement"] == True
        and streak != 0
        and (
        streak % 100 == 0
        or streak % 365 == 0
        or streak in [7, 31, 60]
        or is_repeating_number(streak)
        )
        ):
        s = start_achievement(streak, self)
        s.show()
        write_config("achievement", False)
