# Shigeyuki <https://www.patreon.com/Shigeyuki>

from os.path import join, dirname

from aqt import QPixmap,gui_hooks
from aqt.utils import openLink
from aqt import QAction, QDialog, QHBoxLayout, QIcon, QResizeEvent, QTabWidget, QTextBrowser, QWidget, Qt, qconnect
from aqt import QVBoxLayout, QLabel, QPushButton
from aqt import mw

from ..custom_shige.path_manager import ADDON_ID
from ..config_manager import write_config
from .patreons_list import PATRONS_LIST #🟢
from .button_manager import mini_button
from .endroll.endroll import add_credit_tab
from .shige_addons import add_shige_addons_tab
from ..path_manager import ADDON_NAME

from .change_log import OLD_CHANGE_LOG #🟢

CHANGE_LOG = "shige_chang_log_day"
# CHANGE_LOG_DAY = "2025-04-14g"
# CHANGE_LOG_DAY = "2025-11-06a" #🟢
CHANGE_LOG_DAY = "2026-03-16" #🟢
CHANGE_LOG_DEFAULT = ""
# -> config.manager.pyに追加


#🟢 AnkiWebのﾊﾟﾄﾛﾝのﾘｽﾄを更新
# https://ankiweb.net/shared/info/175794613

SPECIAL_THANKS ="""\
[ Patreon ] Special thanks
Without the support of my Patrons, I would never have been
able to develop this. Thank you very much!🙏"""


# popup-size
# mini-pupup
SIZE_MINI_WIDTH = 637
SIZE_MINI_HEIGHT = 549
# Width: 637, Height: 549

# Large-popup
SIZE_BIG_WIDTH = 600
SIZE_BIG_HEIGHT = 500


POKEBALL_PATH = r"popup_icon.png"

THE_ADDON_NAME = "🏆️Anki Leaderboard (Customized by Shige)"
SHORT_ADDON_NAME = "Anki Leaderboard" # not used

GITHUB_URL = "https://github.com/shigeyukey/my_addons/issues" #🟢



ANKI_WEB_URL = ""
RATE_THIS_URL = ""

if ADDON_ID:
    ADDON_PACKAGE = ADDON_ID
else:
    ADDON_PACKAGE = mw.addonManager.addonFromModule(__name__)

# ｱﾄﾞｵﾝのURLが数値であるか確認
if (isinstance(ADDON_PACKAGE, (int, float))
    or (isinstance(ADDON_PACKAGE, str)
    and ADDON_PACKAGE.isdigit())):
    ANKI_WEB_URL = f"https://ankiweb.net/shared/info/{ADDON_PACKAGE}"
    RATE_THIS_URL = f"https://ankiweb.net/shared/review/{ADDON_PACKAGE}"


PATREON_URL = "http://patreon.com/Shigeyuki"
REDDIT_URL = "https://www.reddit.com/r/Anki/comments/1b0eybn/simple_fix_of_broken_addons_for_the_latest_anki/"

POPUP_PNG = r"popup_shige.png"


#🟢
NEW_FEATURE = """
2026-03-16
[ Enhanced the Home leaderboard ]
    - I've enhanced the Home leaderboard (V2 mode).
        If you want to revert to the previous version please set
        the mode from V2 to Legacy. (Home -> V2 button -> Legacy)
    - I haven't written instructions on how to use the Home yet.
    - Some features are still under development.

[ Enhanced server ]
    - The server was unstable due to increased users so enhanced it again.
    - Occasionally the server may temporarily become congested,
        if so please try again later.

The detailed changelog is a bit long so I've written it in the old changelog.
If you find a problem please contact me.
"""

# [3] Note
#     [1] I have not yet tested all the features.
#         Feel free to contact me if you find any problems.

UPDATE_TEXT = "I updated this add-on."
# UPDATE_TEXT = ""  #League


# CHANGE_LOG_TEXT = """\
# [ Change log : {addon} ]

# Shigeyuki : Hi thanks for using this add-on! {update_text}
# {new_feature}
# ---
# I'm looking for supporters for my add-ons development, because I like Anki! So far I fixed and customized 80+ discontinued add-ons and created 30+ new add-ons. If you support my volunteer development you will get 14 add-ons for patrons only and 15 game themes included in AnkiArcade. If you have any ideas or requests feel free to send them to me., thanks! :D

# [ Old change log ]
# {old_change_log}

# {special_thanks}

# {patron}

# """.format(addon=THE_ADDON_NAME,
#             update_text=UPDATE_TEXT,
#             new_feature=NEW_FEATURE,
#             old_change_log = OLD_CHANGE_LOG,
#             special_thanks=SPECIAL_THANKS,
#             patron=PATRONS_LIST)

patron_url_href = '<a href="https://www.patreon.com/posts/154968535" target="_blank">'

try:
    _Leaderboar_plus_path = join(dirname(dirname(__file__)), "Leaderboard_plus.webp")
    str_Leaderboar_plus_path = (
        f'{patron_url_href}'
        f'<img src="{_Leaderboar_plus_path}"></a>'
    )
except Exception as e:
    print(f"[{ADDON_NAME}] ")
    str_Leaderboar_plus_path = ""


CHANGE_LOG_TEXT = f"""\
[ Change log : {THE_ADDON_NAME} ]

Shigeyuki : Hi thanks for using this add-on! {UPDATE_TEXT}
{NEW_FEATURE}
--------
[ 🎮Shige's Gamification add-ons ] I develop as a hobby and so far I've fixed 80+ broken add-ons for free by request from users and released 30+ original add-ons for free! If you become a patron ($5/month) and support my volunteer development you can download the Patrons only add-on Anki Leaderboard Plus.
{str_Leaderboar_plus_path}
[ {patron_url_href}🏆️Anki Leaderboard Plus (Patrons only)</a> ] Leaderboard displayed on top bar and updated in real time during review! This version added sync speed optimization and enhancements, UI for gamification mode, toast notifications for scores, improved tooltip design, and enhanced options, etc. Revenue from this add-on will be used to maintain and enhance the leaderboard Free server. (Not related to the official Anki.)
--------

[ Old change log ]
{OLD_CHANGE_LOG}

{SPECIAL_THANKS}

{PATRONS_LIST}
"""

# If you become a patron and support my volunteer development, you will be able to download all the patron exclusive gamification add-ons that I'm primarily developing. Currently there are about 30 contents (16 add-ons + AnkiArcarde 15 themes)

# I'm looking for supporters for my add-ons development, because I like Anki! So far I fixed and customized 80+ discontinued add-ons and created 30+ new add-ons. If you support my volunteer development you will get 14 add-ons for patrons only and 15 game themes included in AnkiArcade. If you have any ideas or requests feel free to send them to me., thanks! :D

# 🏆️Anki Leaderboard Plus V3
# Leaderboard displayed on top bar and updated in real time during review! This version added sync speed optimization and enhancements, UI for gamification mode, toast notifications for scores, improved tooltip design, and enhanced options, etc. Revenue from this add-on will be used to maintain and enhance the leaderboard Free server.




# CHANGE_LOG_TEXT_B = """\
# Shigeyuki :
# Hi thanks for using this add-on, I'm Shige!😆 I develop as a hobby and so far I've fixed 80+ broken add-ons for free by request from users and released 30+ original add-ons for free! If you become a patron ($5/month) and support my volunteer development you can download the Patrons only add-on Anki Leaderboard Plus.
# {str_Leaderboar_plus_path}
# [ {patron_url_href}🏆️Anki Leaderboard Plus (Patrons only)</a> ] Leaderboard displayed on top bar and updated in real time during review! This version added sync speed optimization and enhancements, UI for gamification mode, toast notifications for scores, improved tooltip design, and enhanced options, etc. Revenue from this add-on will be used to maintain and enhance the leaderboard Free server.

# ----
CHANGE_LOG_TEXT_B = """\
{addon}
[ Change log ]

{new_feature}

{old_change_log}

----
{special_thanks}

{patron}
""".format(addon=THE_ADDON_NAME,patron=PATRONS_LIST,special_thanks=SPECIAL_THANKS,
            new_feature=NEW_FEATURE, old_change_log=OLD_CHANGE_LOG,
            # str_Leaderboar_plus_path=str_Leaderboar_plus_path,
            # patron_url_href=patron_url_href
            )

# I'm looking for supporters for my add-ons development, because I like Anki! So far I fixed and customized 60+ discontinued add-ons and created 30+ new add-ons. If you support my volunteer development you will get 14 add-ons for patrons only and 15 game themes included in AnkiArcade. Of course even if you are not a supporter feel free to send me your ideas and requests, thanks!


# ------- Change Log PopUp ---------------

def set_gui_hook_change_log():
    gui_hooks.main_window_did_init.append(change_log_popup)
    # gui_hooks.main_window_did_init.append(add_config_button) #🟢


def change_log_popup(*args,**kwargs):
    try:
        config = mw.addonManager.getConfig(__name__)
        if (config.get(CHANGE_LOG, CHANGE_LOG_DEFAULT) != CHANGE_LOG_DAY):
            dialog = CustomDialog(mw, CHANGE_LOG_TEXT, size_mini=True)
            dialog.show()
            write_config(CHANGE_LOG, CHANGE_LOG_DAY)
    except Exception as e:
        pass


def change_log_popup_B(*args,**kwargs):
    try:
        dialog = CustomDialog(mw, CHANGE_LOG_TEXT_B, True)
        dialog.show()
    except Exception as e:
        pass



# ----- add-onのconfigをｸﾘｯｸしたら設定ｳｨﾝﾄﾞｳを開く -----
def add_config_button():
    mw.addonManager.setConfigAction(__name__, change_log_popup_B)
    # ----- ﾒﾆｭｰﾊﾞｰに追加 -----
    action = QAction(THE_ADDON_NAME, mw)
    qconnect(action.triggered, change_log_popup_B)
    mw.form.menuTools.addAction(action)

# ================================================




class CustomDialog(QDialog):
    def __init__(self, parent=None, change_log_text=CHANGE_LOG_TEXT, more_button=False, size_mini=False):
        super().__init__(parent)

        addon_path = dirname(__file__)
        icon = QPixmap(join(addon_path, POPUP_PNG))

        if size_mini:
            self.resize(SIZE_MINI_WIDTH, SIZE_MINI_HEIGHT)
        else:
            self.resize(SIZE_BIG_WIDTH, SIZE_BIG_HEIGHT)

        pokeball_icon = QIcon(join(addon_path, POKEBALL_PATH))
        self.setWindowIcon(pokeball_icon)

        self.setWindowTitle(THE_ADDON_NAME)

        tab_widget = QTabWidget()
        tab = QWidget()
        tab_layout = QVBoxLayout(tab)

        icon_label = QLabel()
        icon_label.setPixmap(icon)

        hbox = QHBoxLayout()

        change_log_label = QTextBrowser()
        change_log_label.setReadOnly(True)
        change_log_label.setOpenExternalLinks(True)

        # change_log_label.setPlainText(change_log_text)

        escaped_text = change_log_text.replace("\n", "<br>")
        html_content = f"""\
<div style="white-space: pre-wrap;">{escaped_text}</div>
"""
        change_log_label.setHtml(html_content)


        hbox.addWidget(icon_label)
        hbox.addWidget(change_log_label)

        tab_layout.addLayout(hbox)

        button_layout = QHBoxLayout()
        button_layout.addStretch()

        self.yes_button = QPushButton("💖Become a Patron")
        self.yes_button.clicked.connect(lambda: openLink(PATREON_URL))
        self.yes_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        mini_button(self.yes_button)

        self.report_button = QPushButton("🚨Report")
        self.report_button.clicked.connect(lambda: openLink(
            "https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html#report-problems-or-requests"
            ))
        self.report_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        mini_button(self.report_button)

        self.no_button = QPushButton("OK (Close)")
        self.no_button.clicked.connect(self.close)
        self.no_button.setFixedWidth(120)

        button_layout.addWidget(self.yes_button)
        button_layout.addWidget(self.report_button)
        button_layout.addWidget(self.no_button)

        tab_widget.addTab(tab, "Change Log")
        add_credit_tab(self, tab_widget)
        add_shige_addons_tab(self, tab_widget)

        main_layout = QVBoxLayout(self)
        main_layout.addWidget(tab_widget)
        main_layout.addLayout(button_layout)

        self.setLayout(main_layout)

    def resizeEvent(self, event:"QResizeEvent"):
        size = event.size()
        print(f"Width: {size.width()}, Height: {size.height()}")
        super().resizeEvent(event)

