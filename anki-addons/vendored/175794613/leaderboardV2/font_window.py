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


from aqt import mw, QTimer, Qt, QFont, QFontComboBox, QHBoxLayout, QDialog, QVBoxLayout, QPushButton, QLabel, QTableWidget
from aqt.utils import openLink

from ..config_manager import write_config
from ..shige_pop.button_manager import mini_button

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from .leaderboardV2 import RebuildLeaderbord, PaginationBoard


class SetFontWindow(QDialog):
    def __init__(self, rebuild, parent=None):
        super().__init__(parent)
        self.parent_window = parent # type: PaginationBoard
        self.rebuild = rebuild # type: RebuildLeaderbord
        if parent == None:
            return
        self.username_list = None
        self.current_font = None

        self.setWindowTitle("Select font")
        self.setGeometry(100, 100, 300, 100)

        self.vbox_layout = QVBoxLayout()

        config = mw.addonManager.getConfig(__name__)
        self.set_font_family = config.get("set_font_family", None)
        self.font_combo_box = QFontComboBox()
        if self.set_font_family:
            self.font_combo_box.setCurrentFont(QFont(self.set_font_family))
        self.font_combo_box.setFixedWidth(300)

        def on_font_changed(font: QFont):
            self.current_font = font.family()
        self.font_combo_box.currentFontChanged.connect(on_font_changed)
        self.vbox_layout.addWidget(self.font_combo_box)

        self.result_label = QLabel(self)
        self.result_label.setText("Select font")
        self.vbox_layout.addWidget(self.result_label)

        hbox = QHBoxLayout()

        self.search_button = QPushButton("OK", self)
        self.search_button.clicked.connect(self.set_font)
        self.search_button.setFixedWidth(100)
        # mini_button(self.search_button)
        hbox.addWidget(self.search_button)

        self.remove_button = QPushButton("Reset", self)
        self.remove_button.clicked.connect(self.reset_font)
        self.remove_button.setFixedWidth(100)
        # mini_button(self.remove_button)
        hbox.addWidget(self.remove_button)

        self.report_button = QPushButton("🚨Report")
        self.report_button.clicked.connect(lambda: openLink("https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html#report-problems-or-requests"))
        self.report_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        mini_button(self.report_button)
        hbox.addWidget(self.report_button)

        # self.wiki_button = QPushButton("📖Wiki")
        # self.wiki_button.setStyleSheet("QPushButton { padding: 2px; }")
        # self.wiki_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        # self.wiki_button.clicked.connect(lambda: openLink(
        #     "https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html#friends"))
        # hbox.addWidget(self.wiki_button)

        hbox.addStretch()
        self.vbox_layout.addLayout(hbox)

        self.setLayout(self.vbox_layout)

        self.center()

    def center(self):
        if self.parent():
            parent_rect = self.parent_window.geometry()
            self_rect = self.geometry()
            x = parent_rect.x() + (parent_rect.width() - self_rect.width()) // 2
            y = parent_rect.y() + (parent_rect.height() - self_rect.height()) // 2
            self.move(x, y)

    def set_font(self):
        font = self.current_font # type: QFont
        if font:
            write_config("set_font_family", font)
            self.result_label.setText("Now loading...")
            QTimer.singleShot(100, self.run_set_font)

    def run_set_font(self):
        self.result_label.setText("Select font.")
        # self.parent_window.reloadPage()
        self.rebuild.reload_leaderboard()


    def reset_font(self):
        write_config("set_font_family", None)
        self.font_combo_box.setCurrentIndex(-1)
        # self.result_label.setText("Please restart the leaderboard.")
        self.rebuild.reload_leaderboard()


