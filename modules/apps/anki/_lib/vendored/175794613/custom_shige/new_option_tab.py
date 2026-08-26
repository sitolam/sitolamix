
import os
import json
from aqt import QFont, QFontComboBox, QFrame, QLabel, QWidget, QTabWidget, QVBoxLayout, QCheckBox, mw
from aqt import  QTextEdit, QHBoxLayout, QPushButton, QDialog
from aqt.utils import tooltip

from ..shige_pop.button_manager import mini_button, mini_button_v3

from ..config_manager import write_config, local_config_overwritten_by_server_config
from ..color_config_window import show_colors_editor

SYNC_CONFIG_NAME = "shige_Anki_leaderboard_config"


class NewOptionTab(QWidget):
    def __init__(self, tab_widget: QTabWidget, parent=None):
        super().__init__(parent)
        config = mw.addonManager.getConfig(__name__)

        #📍tooltipでﾌｨｰﾄﾞﾊﾞｯｸすると良

        # get config
        show_home_buttons  = config.get("show_home_buttons", True)
        add_pic_country_and_league = config.get("add_pic_country_and_league", True)
        sync_multiple_device = config.get("sync_multiple_device", False)
        zoom_enable = config.get("zoom_enable", True)

        gamification_mode =  config.get("gamification_mode", True)
        allways_on_top = config.get("allways_on_top", False)
        start_yesterday = config.get("start_yesterday", True)
        is_online_dot = config.get("is_online_dot", True)
        rate_and_donation_buttons = config.get("rate_and_donation_buttons", True)
        board_position = config.get("board_position", [])
        mini_mode = config.get("mini_mode", False)
        discord_button = config.get("discord_button", True)

        # self.set_font_family = config.get("set_font_family", None)

        new_option_tab = QWidget(self)
        new_option_layout = QVBoxLayout()

        new_option_layout.addWidget(QLabel("<b>[ Graphics ]</b>"))
        # make checkbox
        checkbox_show_home_buttons = QCheckBox("Show Home buttons")
        checkbox_show_home_buttons.setChecked(show_home_buttons)
        checkbox_show_home_buttons.clicked.connect(
            lambda checked: write_config("show_home_buttons", checked))

        checkbox_add_pic_country_and_league = QCheckBox(
            # "Add picture of country, league and profile"
            "Show profile icon (Home board) / Show profile league country icons (Window board)"
            )
        checkbox_add_pic_country_and_league.setChecked(add_pic_country_and_league)
        checkbox_add_pic_country_and_league.clicked.connect(
            lambda checked: write_config("add_pic_country_and_league", checked))

        check_zoom_enable = QCheckBox("Zoom and Font Enable")
        check_zoom_enable.setChecked(zoom_enable)
        check_zoom_enable.clicked.connect(
            lambda checked: write_config("zoom_enable", checked))

        # font_combo_box = QFontComboBox()
        # if self.set_font_family:
        #     font_combo_box.setCurrentFont(QFont(self.set_font_family))
        # font_combo_box.setFixedWidth(300)

        # def on_font_changed(font: QFont):
        #     write_config("set_font_family", font.family())
        # font_combo_box.currentFontChanged.connect(on_font_changed)

        def open_color_window():
            show_colors_editor(self)

        h_box = QHBoxLayout()
        color_setting_button = QPushButton("Color Settings")
        mini_button_v3(color_setting_button)
        color_setting_button.clicked.connect(open_color_window)
        h_box.addWidget(color_setting_button)
        h_box.addStretch()

        new_option_layout.addWidget(checkbox_show_home_buttons)
        new_option_layout.addWidget(checkbox_add_pic_country_and_league)
        new_option_layout.addWidget(check_zoom_enable)
        new_option_layout.addLayout(h_box)
        # new_option_layout.addWidget(font_combo_box)

        new_option_layout.addWidget(self.create_separator())#-------------

        new_option_layout.addWidget(QLabel("<b>[ Sync multiple device ]</b>"))

        checkbox_sync_multiple_device = QCheckBox("Auto save this device's Config data to AnkiWeb")
        checkbox_sync_multiple_device.setChecked(sync_multiple_device)
        checkbox_sync_multiple_device.clicked.connect(
            lambda checked: write_config("sync_multiple_device", checked))
        checkbox_sync_multiple_device.clicked.connect(
            lambda cheked: tooltip("Saved Successfully, please sync Anki.")
            if cheked else tooltip("Auto save stopped."))

        new_option_layout.addWidget(checkbox_sync_multiple_device)

        # if True:
        #     test_func_button = QPushButton("Test func")
        #     test_func_button.setFixedWidth(120)
        #     test_func_button.clicked.connect(lambda: test_func_action(self))
        #     new_option_layout.addWidget(test_func_button)

        hbox = QHBoxLayout()

        download_sync_data_button = QPushButton("Download Config data from AnkiWeb")
        download_sync_data_button.setFixedWidth(270)
        download_sync_data_button.clicked.connect(local_config_overwritten_by_server_config)
        hbox.addWidget(download_sync_data_button)

        delete_sync_data_button = QPushButton("Delete AnkiWeb config data")
        delete_sync_data_button.setFixedWidth(200)
        delete_sync_data_button.clicked.connect(self.remove_config)
        hbox.addWidget(delete_sync_data_button)

        hbox.addStretch()
        new_option_layout.addLayout(hbox)

        new_option_layout.addWidget(self.create_separator())#-------------

        check_gamification_mode = self.create_checkbox(
            "Gamification Mode",
            gamification_mode,
            "gamification_mode",
            lambda checked: tooltip("Enable") if checked else tooltip("Disabled")
        )

        check_start_yesterday = self.create_checkbox(
            "Include yesterday in the calculationy",
            start_yesterday,
            "start_yesterday",
            lambda checked: tooltip("Enable") if checked else tooltip("Disabled")
        )

        check_is_online_dot = self.create_checkbox(
            "Show online status indicator",
            is_online_dot,
            "is_online_dot",
            lambda checked: tooltip("Enable") if checked else tooltip("Disabled")
        )

        check_allways_on_top = self.create_checkbox(
            "Always on top",
            allways_on_top,
            "allways_on_top",
            lambda checked: tooltip("Enable") if checked else tooltip("Disabled")
        )

        check_rate_and_donation_button = self.create_checkbox(
            "show rate and donation buttons",
            rate_and_donation_buttons,
            "rate_and_donation_buttons",
            lambda checked: tooltip("Enable") if checked else tooltip("Disabled")
        )

        mini_mode_button = self.create_checkbox(
            "Mini mode",
            mini_mode,
            "mini_mode",
            lambda checked: tooltip("Enable") if checked else tooltip("Disabled")
        )

        is_discord_buttons = self.create_checkbox(
            "Show Discord Buttons",
            discord_button,
            "discord_button",
            lambda checked: tooltip("Enable") if checked else tooltip("Disabled")
        )


        board_position_button = QPushButton("Reset Window Position")
        mini_button(board_position_button)
        def resset_position():
            write_config("board_position", [])
            tooltip("Position Reset")
        board_position_button.clicked.connect(resset_position)
        hbox02 = QHBoxLayout()
        hbox02.addWidget(board_position_button)
        hbox02.addStretch()

        new_option_layout.addWidget(QLabel("<b>[ Gamification Mode ]</b>"))
        new_option_layout.addWidget(check_gamification_mode)
        new_option_layout.addWidget(check_start_yesterday)
        new_option_layout.addWidget(check_is_online_dot)
        new_option_layout.addWidget(check_allways_on_top)
        new_option_layout.addLayout(hbox02)

        new_option_layout.addWidget(check_rate_and_donation_button)
        
        hbox03 = QHBoxLayout()
        hbox03.addWidget(mini_mode_button)
        hbox03.addWidget(is_discord_buttons)
        hbox03.addStretch()
        new_option_layout.addLayout(hbox03)
        

        new_option_layout.addStretch()

        new_option_tab.setLayout(new_option_layout)
        tab_widget.addTab(new_option_tab, "Others")


    def create_checkbox(self, label, is_checked, config_key, additional_callback=None):
        checkbox = QCheckBox(label)
        checkbox.setChecked(is_checked)

        def on_clicked(checked):
            write_config(config_key, checked)
            if additional_callback:
                additional_callback(checked)

        checkbox.clicked.connect(on_clicked)
        return checkbox


    def remove_config(self):
        sync_config = mw.col.get_config(SYNC_CONFIG_NAME, default=None)
        if sync_config == None:
            tooltip("No data in AnkiWeb :-/")
            return
        mw.col.remove_config(SYNC_CONFIG_NAME)
        sync_config = mw.col.get_config(SYNC_CONFIG_NAME, default=None)
        if sync_config == None:
            tooltip("Success :-)")
        else:
            tooltip("Failure :-/")

    # ｾﾊﾟﾚｰﾀを作成する関数=========================
    def create_separator(self):
        separator = QFrame()
        separator.setFrameShape(QFrame.Shape.HLine)
        separator.setFrameShadow(QFrame.Shadow.Sunken)
        separator.setStyleSheet("border: 1px solid gray")
        return separator
    # =================================================




# class DisplayWindow(QDialog):
#     def __init__(self, data, parent=None):
#         super().__init__(parent)
#         self.initUI(data)

#     def initUI(self, data):
#         self.setWindowTitle('Display Window')
#         self.setGeometry(100, 100, 400, 300)

#         layout = QVBoxLayout()
#         self.text_edit = QTextEdit(self)
#         # self.text_edit.setText(text)
#         self.text_edit.setText(json.dumps(data, indent=4))

#         layout.addWidget(self.text_edit)

#         button_layout = QHBoxLayout()
#         self.ok_button = QPushButton("OK", self)
#         self.cancel_button = QPushButton("Cancel", self)
#         button_layout.addWidget(self.ok_button)
#         button_layout.addWidget(self.cancel_button)
#         layout.addLayout(button_layout)

#         self.ok_button.clicked.connect(self.save_json)
#         self.cancel_button.clicked.connect(self.close)

#         self.setLayout(layout)

#     def save_json(self):
#         try:
#             conf = json.loads(self.text_edit.toPlainText())
#             mw.col.set_config(SYNC_CONFIG_NAME, conf)
#             print(type(conf))
#             print("save date", conf)
#             self.close()
#         except json.JSONDecodeError:
#             print("Invalid JSON format")

# def test_func_action(parent):
#     sync_config = mw.col.get_config(SYNC_CONFIG_NAME, default=None)
#     test_func = DisplayWindow(sync_config, parent)
#     test_func.show()

