# license: see license.txt

import json
import os

from aqt import mw
from anki.hooks import addHook

# from .config import gc


def tinyloader():
    if False: # gc('experimental_paste_support', False):
        from . import DragDropPaste
    else:
        from . import external_js_editor_for_field
addHook('profileLoaded', tinyloader)


def maybe_reset_config():
    old_config = mw.addonManager.getConfig(__name__)
    if "auto_reset_number" not in old_config or old_config["auto_reset_number"] <= 1:
        addon_path = os.path.dirname(__file__)
        json_file_path = os.path.join(addon_path, "config.json")
        with open(json_file_path, encoding="utf8") as f:
            new_default_config = json.load(f)
        new_default_config["auto_reset_number"] = 2
        mw.addonManager.writeConfig(__name__, new_default_config)
addHook('profileLoaded', maybe_reset_config)
