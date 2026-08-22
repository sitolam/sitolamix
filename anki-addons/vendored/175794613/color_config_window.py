# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import json
import copy
from os.path import join, dirname

from aqt.qt import (QVBoxLayout, QHBoxLayout, QPushButton,
                    QLabel, QTabWidget, QWidget, QColorDialog, QGridLayout,
                    QMessageBox, Qt, QColor)
from aqt.utils import tooltip

from .shige_pop.button_manager import mini_button_v3


OLD_DEFAULT_COLORS ={
    "light": {
        "USER_COLOR": "#51f564",
        "FRIEND_COLOR": "#2176ff",
        "GOLD_COLOR": "#ffd700",
        "SILVER_COLOR": "#c0c0c0",
        "BRONZE_COLOR": "#bf8970",
        "ROW_LIGHT": "#ffffff",
        "ROW_DARK": "#f5f5f5",
        "LEAGUE_TOP": "#abffc7",
        "LEAGUE_BOTTOM": "#f75e5e",
        "LEAGUE_BOTTOM_USER": "#d14f4f"
    },
    "dark": {
        "USER_COLOR": "#0aad1d",
        "FRIEND_COLOR": "#0058e6",
        "GOLD_COLOR": "#ccac00",
        "SILVER_COLOR": "#999999",
        "BRONZE_COLOR": "#a7684a",
        "ROW_LIGHT": "#3A3A3A",
        "ROW_DARK": "#2F2F31",
        "LEAGUE_TOP": "#42a663",
        "LEAGUE_BOTTOM": "#b83333",
        "LEAGUE_BOTTOM_USER": "#9e2c2c"
    }
}

NEW_DEFAULT_COLORS ={
    "light": {
        "USER_COLOR": "#ceffce",
        "FRIEND_COLOR": "#d9edff",
        "GOLD_COLOR": "#fffab3",
        "SILVER_COLOR": "#d5d5d5",
        "BRONZE_COLOR": "#f8d1c0",
        "ROW_LIGHT": "#ffffff",
        "ROW_DARK": "#f5f5f5",
        "LEAGUE_TOP": "#e1fff4",
        "LEAGUE_BOTTOM": "#f7b8b8",
        "LEAGUE_BOTTOM_USER": "#f7b8b8"
    },
    "dark": {
        "USER_COLOR": "#4a614d",
        "FRIEND_COLOR": "#334170",
        "GOLD_COLOR": "#95923a",
        "SILVER_COLOR": "#7d7d7d",
        "BRONZE_COLOR": "#8c6549",
        "ROW_LIGHT": "#3A3A3A",
        "ROW_DARK": "#2F2F31",
        "LEAGUE_TOP": "#365255",
        "LEAGUE_BOTTOM": "#582828",
        "LEAGUE_BOTTOM_USER": "#582828"
    }
}


class ColorButton(QPushButton):
    def __init__(self, color_hex):
        super().__init__()
        self.setColor(color_hex)
        self.clicked.connect(self.chooseColor)
        self.setMinimumWidth(100)

    def setColor(self, color_hex):
        self.color_hex = color_hex
        self.setStyleSheet(f"background-color: {color_hex};")

    def chooseColor(self):
        current_color = QColor(self.color_hex)
        color_dialog = QColorDialog()
        # color_dialog.setOption(QColorDialog.ColorDialogOption.ShowAlphaChannel, True)
        color_dialog.setCurrentColor(current_color)

        if color_dialog.exec() == QColorDialog.DialogCode.Accepted:
            new_color = color_dialog.currentColor()
            hex_color = new_color.name(QColor.NameFormat.HexRgb) # no alphaChannel
            self.setColor(hex_color)

            parent = self.parent() # type: ColorsEditorDialog
            while parent and not hasattr(parent, 'saveColors'):
                parent = parent.parent()
            if parent and hasattr(parent, 'saveColors'):
                parent.saveColors()


class ColorsEditorDialog(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlag(Qt.WindowType.Window)
        self.setWindowTitle("Leaderboard Color Settings by Shigeඞ")
        self.resize(500, 500)

        self.loadColors()
        self.setupUI()

    def loadColors(self):
        addon_path = dirname(__file__)
        user_files_dir = join(addon_path, "user_files")
        self.color_config_path = join(user_files_dir, "colors.json")

        with open(self.color_config_path, "r") as colors_file:
            self.colors = json.load(colors_file)


    def setupUI(self):
        layout = QVBoxLayout()
        tabs = QTabWidget()

        self.color_buttons = {}

        ### tab 1 ###
        light_tab = self.createColorTab("light")
        tabs.addTab(light_tab, "Light Mode")

        ### tab 2 ###
        dark_tab = self.createColorTab("dark")
        tabs.addTab(dark_tab, "Dark Mode")

        ### tab 3 ###
        restore_tab = QWidget()
        reset_layout = QVBoxLayout()

        h_box = QHBoxLayout()
        restore_button = QPushButton("Restore Default Colors")
        mini_button_v3(restore_button)
        restore_button.clicked.connect(self.resetColors)
        h_box.addWidget(restore_button)
        h_box.addStretch()

        reset_layout.addLayout(h_box)

        h_box = QHBoxLayout()
        restore_old_button = QPushButton("Restore Old Colors")
        mini_button_v3(restore_old_button)
        restore_old_button.clicked.connect(lambda: self.resetColors(old_color=True))
        h_box.addWidget(restore_old_button)
        h_box.addStretch()

        reset_layout.addLayout(h_box)



        reset_layout.addStretch()
        restore_tab.setLayout(reset_layout)
        tabs.addTab(restore_tab, "Others")


        ### add all tabs ###
        layout.addWidget(tabs)

        ### buttons ###
        button_layout = QHBoxLayout()
        button_layout.addStretch()

        # ok_button = QPushButton("OK")
        # ok_button.clicked.connect(self.saveColors)

        cancel_button = QPushButton("Close")
        cancel_button.clicked.connect(self.close)

        # button_layout.addWidget(ok_button)
        button_layout.addWidget(cancel_button)

        layout.addLayout(button_layout)
        self.setLayout(layout)

    def createColorTab(self, mode):
        tab = QWidget()
        grid_layout = QGridLayout()

        row = 0
        if mode not in self.color_buttons:
            self.color_buttons[mode] = {}

        for color_key, color_value in self.colors[mode].items():
            label = QLabel(color_key)
            color_button = ColorButton(color_value)
            color_button.setParent(self)
            self.color_buttons[mode][color_key] = color_button
            grid_layout.addWidget(label, row, 0)
            grid_layout.addWidget(color_button, row, 1)
            row += 1

        tab.setLayout(grid_layout)
        return tab

    def resetColors(self, old_color=False):
        reply = QMessageBox.question(self, 'Restore Colors',
                                    'Are you sure you want to reset all colors to default? :-/',
                                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                                    QMessageBox.StandardButton.No)
        if reply == QMessageBox.StandardButton.Yes:
            if old_color:
                colors_set = OLD_DEFAULT_COLORS
            else:
                colors_set = NEW_DEFAULT_COLORS
            self.colors = copy.deepcopy(colors_set)
            for mode in ["light", "dark"]:
                for color_key, color_value in self.colors[mode].items():
                    self.color_buttons[mode][color_key].setColor(color_value)
                with open(self.color_config_path, "w") as colors_file:
                    json.dump(self.colors, colors_file, indent=4)
            tooltip("Restore to default! :-)")

    def saveColors(self):
        for mode in ["light", "dark"]:
            for color_key, button in self.color_buttons[mode].items():
                self.colors[mode][color_key] = button.color_hex
        with open(self.color_config_path, "w") as colors_file:
            json.dump(self.colors, colors_file, indent=4)
        tooltip("Saved! :-)")

def show_colors_editor(parent=None):
    dialog = ColorsEditorDialog(parent)
    return dialog.show()

