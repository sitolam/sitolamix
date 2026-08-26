import os

import aqt
from aqt.qt import *
from aqt.utils import showInfo, askUser

from .config import addon_folder_abs_path, css_folder
if qtmajor == 5:
    from .forms5 import syntax_settings
    from .forms5 import deck_default
else:
    from .forms6 import syntax_settings
    from .forms6 import deck_default
from .fuzzy_panel import FilterDialog
from .checkdialog import CheckDialog
from .dialog_text_display import Text_Displayer
from .pygments_helper import (
    LANG_MAP,
)

class DefaultForDeckAdd(QDialog):
    def __init__(self, parent):
        self.parent = parent
        QDialog.__init__(self, parent, Qt.WindowType.Window)
        self.dialog = deck_default.Ui_Dialog()
        self.dialog.setupUi(self)
        self.setWindowTitle("Set Default Lang for Deck")
        self.dialog.pb_lang.clicked.connect(self.onLang)
        self.dialog.pb_lang.setText("select")
        self.dialog.pb_deck.clicked.connect(self.onDeck)
        self.dialog.pb_deck.setText("select")
        self.dialog.ql_deck.setText("")
        self.dialog.ql_lang.setText("")
        self.deck = ""
        self.lang = ""

    def onDeck(self):
        alldecks = aqt.mw.col.decks.allNames()
        d = FilterDialog(parent=self, values=alldecks)
        if d.exec():
            self.dialog.ql_deck.setText(d.selkey)

    def onLang(self):
        d = FilterDialog(parent=self, values=list(LANG_MAP.keys()))
        if d.exec():
            self.dialog.ql_lang.setText(d.selkey)

    def accept(self):
        self.deck = self.dialog.ql_deck.text()
        self.lang = self.dialog.ql_lang.text()
        QDialog.accept(self)


class ConfigWindowMain(QDialog):
    def __init__(self, parent, config):
        self.parent = parent
        self.config = config
        self.config['cssclasses'] = True
        QDialog.__init__(self, parent, Qt.WindowType.Window)
        self.dialog = syntax_settings.Ui_Dialog()
        self.dialog.setupUi(self)
        self.setWindowTitle("Syntax Highlighting for Code options")
        self.applyconfig()
        self.setbuttons()
        self.favorites = self.config['favorites']
        decklist = []
        if self.config['deckdefaultlang']:
            for k, v in self.config['deckdefaultlang'].items():
                decklist.append(k + '   (' + v + ')')
        self.decklist = sorted(decklist)
        self.settable(self.dialog.lw_deckdefaults, self.decklist)
        self.settable(self.dialog.lw_favs, self.favorites)

    def setbuttons(self):
        self.dialog.pb_setFont.clicked.connect(self.onSelectFont)
        self.dialog.pb_resetFont.clicked.connect(self.onResetFont)
        self.dialog.pb_setstyle.clicked.connect(self.onSelectStyle)
        self.dialog.pb_setstyle_nm.clicked.connect(lambda _:self.onSelectStyle(True))
        self.dialog.pb_up.clicked.connect(self.onListUp)
        self.dialog.pb_down.clicked.connect(self.onListDown)
        self.dialog.pb_add.clicked.connect(self.onListAdd)
        self.dialog.pb_delete.clicked.connect(self.onListDelete)
        self.dialog.pb_deck_def_add.clicked.connect(self.add_default_for_deck)
        self.dialog.pb_deck_def_del.clicked.connect(self.del_default_for_deck)
        self.dialog.pb_setDefLang.clicked.connect(self.on_select_default_lang)
        self.dialog.cb_defaultlangperdeck.stateChanged.connect(self.ondeckdefaultchange)
        self.dialog.pb_about.clicked.connect(self.on_about)

    def on_about(self):
        with open(os.path.join(addon_folder_abs_path, "license.txt")) as f:
            text = f.read()
        help_text = """
If you have problems with this add-on:
1. Read [this Anki FAQ](https://faqs.ankiweb.net/when-problems-occur.html)
2. Disable all other add-ons, then restart Anki and then try again. If this solves your problem you have an add-on conflict and must decide which add-on is more important for you.
3. If you still have problems, reset the config of this add-on and restart Anki and try again.
4. If it still doesn't work you report the problem at https://forums.ankiweb.net/t/syntax-highlighting-enhanced-fork-official-thread/658 and describe the exact steps needed to reproduce the problem.

Anki changes with each update and sometimes this breaks add-ons or changes how they work. So if an add-on no longer works as expected after an add-on: Make sure to have the latest version by manually  checking for add-on updates. Then also have a look at the add-on listing on ankiweb, e.g. https://ankiweb.net/shared/info/1972239816 for this add-on. On these pages add-on creators often  list changes for their add-ons.






"""
        td = Text_Displayer(
            parent=self,
            text=help_text + text,
            windowtitle="about the add-on syntax_highlighting_fork...",
            dialogname_for_restore="about_syntax_highlighting_fork_dialog",
            )
        td.show()

    def ondeckdefaultchange(self):
        if self.dialog.cb_defaultlangperdeck.isChecked():
            self.dialog.wid_deckdefaults.setVisible(True)
        else:
            self.dialog.wid_deckdefaults.setVisible(False)

    def applyconfig(self):
        self.dialog.le_shortcut.setText(self.config['hotkey'])
        self.dialog.cb_center.setChecked(self.config['centerfragments'])
        self.dialog.cb_showPreCode.setChecked(self.config['show pre/code'])
        self.dialog.cb_linenum.setChecked(self.config['linenos'])
        self.dialog.cb_remove_leading_spaces.setChecked(self.config['remove leading spaces if possible'])
        self.dialog.cb_defaultlangperdeck.setChecked(self.config['defaultlangperdeck'])
        self.ondeckdefaultchange()
        if self.config['font']:
            self.dialog.lab_Font_selected.setText(self.config['font'])
        self.dialog.lab_style_selected.setText(self.config['style'])
        self.dialog.lab_style_selected_nm.setText(self.config['style_nm'])
        self.dialog.ql_deflang.setText(self.config['defaultlang'])

    def settable(self, listwidget, _list):
        listwidget.clear()
        listwidget.addItems(_list)
        listwidget.repaint()

    def onSelectFont(self):
        if qtmajor == 5:
            prelim = QFontDatabase().families()
        else:
            prelim = QFontDatabase.families(QFontDatabase.WritingSystem.Any)
        # remove foundry names that Qt adds
        f = [x.split(" [")[0] for x in prelim]
        f = list(set(f))  # remove duplicates
        f.append('default - unset')
        d = FilterDialog(parent=None, values=sorted(f))
        if d.exec():
            self.dialog.lab_Font_selected.setText(d.selkey)

    def onResetFont(self):
        self.dialog.lab_Font_selected.setText("default - unset")

    def onSelectStyle(self, for_night_mode=False):
        all_css_styles = [f.replace(".css", "") for f in os.listdir(css_folder) if f.endswith("css")]
        d = FilterDialog(parent=None, values=all_css_styles)
        if d.exec():
            if for_night_mode:
                self.dialog.lab_style_selected_nm.setText(d.selkey)
            else:
                self.dialog.lab_style_selected.setText(d.selkey)

    def onListUp(self):
        self.moveInList(-1)

    def onListDown(self):
        self.moveInList(1)

    def moveInList(self, arg):
        lw = self.dialog.lw_favs
        row = lw.currentRow()
        thisitem = lw.takeItem(row)
        lw.insertItem(row + arg, thisitem)
        lw.setCurrentRow(row + arg)

    def onListAdd(self):
        d = FilterDialog(parent=None, values=LANG_MAP)
        if d.exec():
            self.dialog.lw_favs.addItem(d.selkey)

    def onListDelete(self):
        lw = self.dialog.lw_favs
        lw.takeItem(lw.currentRow())

    def on_select_default_lang(self):
        d = FilterDialog(parent=self, values=list(LANG_MAP.keys()))
        if d.exec():
            self.dialog.ql_deflang.setText(d.selkey)

    def add_default_for_deck(self):
        d = DefaultForDeckAdd(self)
        if d.exec():
            if d.deck and d.lang:
                text = d.deck + '   (' + d.lang + ')'
                self.decklist.append(text)
                self.decklist.sort()
                self.settable(self.dialog.lw_deckdefaults, self.decklist)

    def del_default_for_deck(self):
        row = self.dialog.lw_deckdefaults.currentRow()
        if row > -1:  # 'if row' doesn't work because the first index is 0.
            del self.decklist[row]
            self.settable(self.dialog.lw_deckdefaults, self.decklist)

    def reject(self):
        QDialog.reject(self)

    def accept(self):
        # https://stackoverflow.com/questions/4629584/pyqt4-how-do-you-iterate-all-items-in-a-qlistwidget
        favs = [str(self.dialog.lw_favs.item(i).text()) for i in range(self.dialog.lw_favs.count())]
        if len(favs) < 1:
            showInfo('select as least one favorite language. Returning to config ...')
            return
        try:
            shortcut = self.dialog.le_shortcut.text()
        except:
            showInfo('You must set a shortcut. Returning to config ...')
            return
        # convert default deck list to dict
        defaultdict = {}
        for i in range(self.dialog.lw_deckdefaults.count()):
            text = str(self.dialog.lw_deckdefaults.item(i).text())
            deck, _, lang = text.rpartition('   (')
            defaultdict[deck] = lang[:-1]  # -1 because I attach ')'
        if self.dialog.lab_Font_selected.text() == "default - unset":
            myfont = ""
        else:
            myfont = self.dialog.lab_Font_selected.text()
        self.config = {
            "show pre/code": self.dialog.cb_showPreCode.isChecked(),
            "centerfragments": self.dialog.cb_center.isChecked(),
            "defaultlangperdeck": self.dialog.cb_defaultlangperdeck.isChecked(),
            "deckdefaultlang": defaultdict,
            "defaultlang": self.dialog.ql_deflang.text(),
            "favorites": favs,
            "hotkey": shortcut,
            "linenos": self.dialog.cb_linenum.isChecked(),
            "remove leading spaces if possible": self.dialog.cb_remove_leading_spaces.isChecked(),
            "style": self.dialog.lab_style_selected.text(),
            "style_nm": self.dialog.lab_style_selected_nm.text(),
            "font": myfont,
        }
        QDialog.accept(self)
