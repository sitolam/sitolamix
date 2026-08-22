# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import time
import threading

from . import shigeAPI

# for Discord RP add-on (prototype)

class APILeaderboardData:
    def __init__(self):
        self._data = {}
        self._lock = threading.Lock()

    def save_data(self, key, value):
        with self._lock:
            self._data[key] = value
            self._data[TIME_STAMP] = time.time()

    def get_data(self, key):
        with self._lock:
            return self._data.get(key)


_leaderboard_data = APILeaderboardData()


shigeAPI.leaderboard_data.add(_leaderboard_data.get_data)

RESPONSE_JSON = "response_json"
USER_NAME = "user_name"
TIME_STAMP = "time_stamp"

# e.g.
# _leaderboard_data.save_data("user1", 100)
# score = _leaderboard_data.get_data("user1")

#📍
# ﾘｽﾄや辞書は使用するときにcopy.deepcopyが必要
# ｲﾐｭｰﾀﾌﾞﾙ(不変)ｵﾌﾞｼﾞｪｸﾄはｺﾋﾟｰ不要
# import copy
# _response_json = shigeAPI.leaderboard_data.call(RESPONSE_JSON) #type: list
# self.response_json = copy.deepcopy(_response_json)