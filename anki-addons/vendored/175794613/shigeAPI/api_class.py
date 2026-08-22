# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>｣

from aqt import mw

class ShigeAPI():
    def __init__(self, new_attr_name:str):
        self.attr_name = "shigeAPI_" + new_attr_name

    def run(self):
        try:
            if hasattr(mw, self.attr_name):
                mw_addon_func = getattr(mw, self.attr_name)
                if callable(mw_addon_func):
                    mw_addon_func()
        except Exception as e:
            print(f"shigeAPI {self.attr_name} Error: {e}")

    def call(self, *args, **kwargs):
        try:
            if hasattr(mw, self.attr_name):
                mw_addon_func = getattr(mw, self.attr_name)
                if callable(mw_addon_func):
                    return mw_addon_func(*args, **kwargs)
        except Exception as e:
            print(f"shigeAPI {self.attr_name} Error: {e}")
        return None

    def add(self, func):
        setattr(mw, self.attr_name, func)

    def check(self):
        return hasattr(mw, self.attr_name) and callable(getattr(mw, self.attr_name, None))