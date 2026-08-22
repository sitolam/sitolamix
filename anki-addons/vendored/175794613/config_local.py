# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import os
import json

from .path_manager import ADDON_NAME


LOCAL_CONFIG_FILE_NAME = "local_config.json"

DEFAULT_CONFIG = {
    "is_show_user_bio": True,
    "max_users_v2": 10,
    "lb_home_mode": "Game"
}

def get_user_files_path():
    addon_path = os.path.dirname(__file__)
    save_directory = os.path.join(addon_path, "user_files")
    if not os.path.exists(save_directory):
        os.makedirs(save_directory)
    return save_directory


def get_save_path():

    save_directory = get_user_files_path()

    local_config_path = os.path.join(save_directory, LOCAL_CONFIG_FILE_NAME)

    if not os.path.exists(local_config_path):
        with open(local_config_path, "w", encoding="utf-8") as f:
            json.dump(DEFAULT_CONFIG, f, ensure_ascii=False, indent=4)

    return local_config_path


def get_local_config():

    try:
        local_config_path = get_save_path()

        with open(local_config_path, "r", encoding="utf-8") as f:
                local_config = json.load(f)

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")
        local_config = DEFAULT_CONFIG

    return local_config


def save_local_config(local_config):
    try:
        local_config_path = get_save_path()

        with open(local_config_path, "w", encoding="utf-8") as f:
            json.dump(local_config, f, ensure_ascii=False, indent=4)

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")
