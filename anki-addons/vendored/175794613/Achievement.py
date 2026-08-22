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

from aqt import QRect, QSizePolicy
from aqt.qt import QMovie, QDialog, Qt, QIcon, QPixmap, qtmajor
from os.path import dirname, join, realpath

if qtmajor > 5:
    from .forms.pyqt6UI import achievement
else:
    from .forms.pyqt5UI import achievement


class start_achievement(QDialog):
    def __init__(self, value, parent=None):
        self.parent = parent
        QDialog.__init__(self, parent, Qt.WindowType.Window)
        self.dialog = achievement.Ui_Dialog()
        self.dialog.setupUi(self)
        self.value = value
        self.setupUI()

    def setupUI(self):
        self.gif = QMovie(join(dirname(realpath(__file__)), 'designer/gifs/confetti.gif'))
        self.dialog.confetti.setMovie(self.gif)
        self.gif.start()

        icon = QIcon()
        icon.addPixmap(QPixmap(join(dirname(realpath(__file__)), "designer/icons/krone.png")), QIcon.Mode.Normal, QIcon.State.Off)
        self.setWindowIcon(icon)

        # self.dialog.message.setText(f"{self.value} day streak!")
        self.dialog.message.setGeometry(QRect(0, 0, 358, 279))
        self.dialog.message.setAlignment(Qt.AlignmentFlag.AlignCenter)

        if isinstance(self.value, int) and self.value % 365 == 0:
            years = self.value // 365
            year_text = "year" if years == 1 else "years"
            self.dialog.message.setText(f"{self.value} day streak!<br>That's {years} {year_text}!")
        else:
            self.dialog.message.setText(f"{self.value} day streak!")