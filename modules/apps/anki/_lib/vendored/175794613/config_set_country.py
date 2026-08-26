# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

from aqt import QHBoxLayout, QSizePolicy, mw, QDialog, QWidget, QVBoxLayout, QPushButton, QLabel

from .config_manager import write_config
from .custom_shige.searchable_combobox import SearchableComboBox
from .custom_shige.country_dict import COUNTRY_LIST, COUNTRY_FLAGS
from .create_icon import create_leaderboard_icon


class SetCountryWindow(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.parent_window = parent # type: QWidget
        if parent == None:
            return
        self.username_list = None

        self.setWindowTitle("Select your Country")
        self.setGeometry(100, 100, 300, 100)

        self.vbox_layout = QVBoxLayout()

        self.search_input = SearchableComboBox(self)
        self.vbox_layout.addWidget(self.search_input)

        for country_name in COUNTRY_LIST:
            # display_name = country_name.replace(' ', '')
            display_name = country_name
            flag_icon_file_path = COUNTRY_FLAGS.get(country_name.replace(" ", ""), "pirate.png")
            country_icon = create_leaderboard_icon(file_name=flag_icon_file_path,
                                                icon_type="flag")
            # self.search_input.addItem(country_icon, display_name, country_name.replace(' ', ''))
            self.search_input.addItem(country_icon, display_name, country_name)

            # self.search_input.addItem(i)

        config = mw.addonManager.getConfig(__name__)
        country = config.get("country", "Country")
        if country not in COUNTRY_LIST:
            country = "Country"
        # self.search_input.setCurrentText(country)
        # index = self.search_input.findText(country)
        index = self.search_input.findData(country)
        if index != -1:
            self.search_input.setCurrentIndex(index)

        self.result_label = QLabel(self)
        self.result_label.setText("Select your Country")
        self.vbox_layout.addWidget(self.result_label)

        hbox = QHBoxLayout()

        self.search_button = QPushButton("Join", self)
        self.search_button.clicked.connect(self.set_country)
        self.search_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        self.search_button.setStyleSheet("QPushButton { padding: 2px; }")
        hbox.addWidget(self.search_button)

        self.remove_button = QPushButton("Leave", self)
        self.remove_button.clicked.connect(self.remove_country)
        self.remove_button.setStyleSheet("QPushButton { padding: 2px; }")
        self.remove_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        hbox.addWidget(self.remove_button)

        # self.wiki_button = QPushButton("📖Wiki")
        # self.wiki_button.setStyleSheet("QPushButton { padding: 2px; }")
        # self.wiki_button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
        # self.wiki_button.clicked.connect(lambda: openLink(
        #     "https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html#friends"))
        # hbox.addWidget(self.wiki_button)

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

    def set_country(self):
        country = self.search_input.currentData()
        if country is None:
            return
        # country = self.search_input.currentText()

        if country not in COUNTRY_LIST:
            country = "Country"
        write_config("country", country)

        config = mw.addonManager.getConfig(__name__)
        country = config.get("country", "Country")
        if not country == "Country":
            self.result_label.setText(f"You joined {country}! :-)")


    def remove_country(self):
        country = "Country"
        write_config("country", country)
        self.result_label.setText(f"You become a pirate :-O")

