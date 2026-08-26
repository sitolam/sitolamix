# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

try:
    from PyQt6.QtCore import QTimer
except:
    from aqt.qt import QTimer

ADDON_NAME = "delayTimer"

INT_MSEC_DELAY = 200

class DelayStartTimer:
    # 関数の連続実行を避けるため一番最後のﾘｸｴｽﾄのみをn秒後に実行

    def __init__(self):
        self.msec_delay = INT_MSEC_DELAY
        self._int_delay_timer_id = 0
        self.func = None

    def _on_delay_start(self, int_delay_timer_id):
        try:

            if int_delay_timer_id != self._int_delay_timer_id:
                return

            #📍run code here
            if callable(self.func):
                self.func()

        except Exception as e:
            print(f"[{ADDON_NAME}] {e}")

    def need_delay_start(self, func):
        try:
            self.func = func

            self._int_delay_timer_id += 1
            int_delay_timer_id = self._int_delay_timer_id

            QTimer.singleShot(
                self.msec_delay,
                lambda:self._on_delay_start(int_delay_timer_id)
                )

        except Exception as e:
            print(f"[{ADDON_NAME}] {e}")


delay_start_timer = DelayStartTimer()
