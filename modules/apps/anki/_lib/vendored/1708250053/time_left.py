# The code of MDS_Time_Left was used.
# MDS_Time_Left
# https://github.com/cjdduarte/MDS_Time_Left

# Copyright:
#       (c) Carlos Duarte 2019-2024 <https://github.com/cjdduarte>
#       (c) Shigeyuki 2024 <https://www.patreon.com/Shigeyuki>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


from aqt import mw
from .path_manager import ADDON_NAME

ONE_DAY_SECONDS = 86400
SEC_ONE_MINUTE = 60

_average_per_card = None


#MARK:reset chache
def reset_cache():
    global _average_per_card
    _average_per_card = None


#MARK:get card time
def get_cards_average_time():
    try:
        global _average_per_card

        config = mw.addonManager.getConfig(__name__)

        if hasattr(mw.col.sched, "day_cutoff"):
            day_cutoff = mw.col.sched.day_cutoff
        elif hasattr(mw.col.sched, "dayCutoff"):
            day_cutoff = mw.col.sched.dayCutoff
        else:
            print(f"[{ADDON_NAME}] Error: day_cutoff not found")
            return 0

        days_to_consider = config.get("days_to_consider", 4) # 4 -> 過去3日

        total_seconds = ONE_DAY_SECONDS * days_to_consider
        cutoff_time = day_cutoff - total_seconds

        query = """
            SELECT
                count(),
                sum(time) / 1000
            FROM
                revlog
            WHERE
                id > ?
        """

        msec_cutoff = cutoff_time * 1000
        done_cards, sum_time = mw.col.db.first(query, msec_cutoff)

        if done_cards is None:
            done_cards = 0

        if sum_time is None:
            sum_time = 0

        min_per_card = config.get("sec_min_per_card", 3)
        max_per_card = config.get("sec_max_per_card", 60)

        if done_cards > 0:
            average_per_card = sum_time / done_cards
            average_per_card = max(min_per_card, average_per_card)
            average_per_card = min(max_per_card, average_per_card)
        else:
            average_per_card = min_per_card

        # save to global
        _average_per_card = average_per_card

        return average_per_card

    except Exception as e:
        print(f"[{ADDON_NAME}] Error in get_cards_average_time: {e}")
        return 0


#MARK:estimate
def estimate_time_left(remain_cards):
    try:
        global _average_per_card

        if _average_per_card is None:
            average_per_card = get_cards_average_time()
        else:
            average_per_card = _average_per_card

        # print(f"[{ADDON_NAME}] avg. {average_per_card}sec/card ")

        minutes = max(0, int(remain_cards * average_per_card / 60))

        left_minutes = f"left {minutes} min"

        return left_minutes

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")
        return ""