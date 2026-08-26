import os

from aqt import mw


addon_folder_abs_path = os.path.dirname(__file__)
css_folder = os.path.join(addon_folder_abs_path, "css")
user_files_folder = os.path.join(addon_folder_abs_path, "user_files")


def gc(arg, fail=False):
    conf = mw.addonManager.getConfig(__name__)
    if conf:
        return conf.get(arg, fail)
    else:
        return fail


def wc(arg, val):
    config = mw.addonManager.getConfig(__name__)
    config[arg] = val
    mw.addonManager.writeConfig(__name__, config)


# Syntax Highlighting (Enhanced Fork) has the id 1972239816 which 
# is loaded after "extended html editor for fields and card templates (with some versioning)"
# with the id 1043915942
try:
    ex_html_edi = __import__("1043915942").dialog_cm.CmDialogBase
except:
    ex_html_edi = False
