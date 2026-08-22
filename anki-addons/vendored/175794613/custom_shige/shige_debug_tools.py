# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

# import os
import json
from requests.models import Response

from ..path_manager import ADDON_NAME


def print_debug_data(response:Response):
    try:

        from ..config_local import get_local_config
        if get_local_config().get("debug_mode"):
            debug_data_json = response.headers.get('X-shige-debug-data')
            if debug_data_json:
                debug_data = json.loads(debug_data_json)
                for line in debug_data:
                    print(f"[{ADDON_NAME}] {line}")

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")
