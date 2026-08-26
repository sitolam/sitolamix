# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

from aqt import mw, gui_hooks

from .config_local import get_local_config, save_local_config
from .path_manager import ADDON_NAME


#MARK:crash checker
def check_anki_crash_flag():
    try:

        lo_config = get_local_config()

        if lo_config.get("crash_check", False):
            # もしAnkiが正常に終了しなければHomeを無効化
            config = mw.addonManager.getConfig(__name__)
            config["homescreen"] = False
            mw.addonManager.writeConfig(__name__, config)

        lo_config["crash_check"] = True # ﾁｪｯｸ
        save_local_config(lo_config)

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e} ")


def on_anki_close_fine(*args, **kwargs):
    try:
        lo_config = get_local_config()
        lo_config.get("crash_check", False)
        lo_config["crash_check"] = False # 正常終了
        save_local_config(lo_config)
    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e} ")


def set_crash_check_hook():
    try:
        gui_hooks.profile_did_open.append(check_anki_crash_flag)
        gui_hooks.profile_will_close.append(on_anki_close_fine)
    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e} ")

