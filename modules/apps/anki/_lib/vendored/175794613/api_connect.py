# Anki Leaderboard
# Copyright (C) 2020 - 2024 Thore Tyborski <https://github.com/ThoreBor>
# Copyright (C) 2024 Shigeyuki <http://patreon.com/Shigeyuki>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# import json
import requests
# from aqt.utils import showWarning, tooltip

from .custom_shige.random_error import custom_error
from .custom_shige.path_manager import POST_REQUEST, LEADERBOARD_URL

from .api_constants import GET_TIMEOUT, POST_TIMEOUT


SESSION = requests.Session()

def get_requests_session():
    return SESSION

def postRequest(endpoint, data, statusCode, warning=True):

    url = f"{POST_REQUEST}{endpoint}"

    try:
        # response = SESSION.post(url, data=data, timeout=15)
        int_timeout = POST_TIMEOUT

        if endpoint == "getUserinfo/":
            int_timeout = 10

        response = SESSION.post(url, data=data, timeout=int_timeout)

        if response.status_code == statusCode:
            return response
        else:
            if warning:
                custom_error(str(response.text))
                # showWarning(str(response.text))
                return False
            else:
                return response
    except Exception as e:
        errormsg = f"Timeout error [{url}] - No internet connection, or server response took too long. \n\n{str(e)}"
        if warning:
            custom_error(str(errormsg))
            # showWarning(errormsg, title="Leaderboard Error")
            return False
        else:
            return errormsg



def getRequest(endpoint, warning=True):
    #url = f"{POST_REQUEST}{endpoint}"
    url = f"{POST_REQUEST}{endpoint}"
    try:
        # response = SESSION.get(url, timeout=15)
        response = SESSION.get(url, timeout=GET_TIMEOUT)

        if response.status_code == 200:
            return response
        else:
            if warning:
                custom_error(str(response.text))
                # showWarning(str(response.text))
            return False
    except Exception as e:
        if warning:
            custom_error()
        # showWarning(f"Timeout error [{url}] - No internet connection, or server response took too long. \n\n{str(e)}", title="Leaderboard Error")
        return False






# test
def getRequestV2(endpoint, statusCode, warning=True):
    #url = f"{POST_REQUEST}{endpoint}"
    url = f"{LEADERBOARD_URL}{endpoint}"
    try:
        response = SESSION.get(url, timeout=10)

        if response.status_code == statusCode:
            return response
        else:
            if warning:
                custom_error(str(response.text))
                return False
            else:
                return response
    except Exception as e:
        errormsg = f"Timeout error [{url}] - No internet connection, or server response took too long. \n\n{str(e)}"
        if warning:
            custom_error(str(errormsg))
            # showWarning(errormsg, title="Leaderboard Error")
            return False
        else:
            return errormsg

