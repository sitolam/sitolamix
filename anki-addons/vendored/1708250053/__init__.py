# Anki Add-on: Progress Bar
# Copyright:
    # (c) Unknown author (nest0r/Ja-Dark?) 2017
    # (c) SebastienGllmt 2017 <https://github.com/SebastienGllmt/>
    # (c) Glutanimate 2017-2018 <https://glutanimate.com/>
    # (c) liuzikai 2018-2020 <https://github.com/liuzikai>
    # (c) BluMist 2022 <https://github.com/BluMist>
    # (c) Unknown author 2023
    # (c) Shigeyuki 2024-2026 <https://www.patreon.com/Shigeyuki>

# Shows progress in the Reviewer in terms of passed cards per session.
#
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

from .progress_bar_main import set_PB_hooks
from .shige_config.progressbar_config import setup_config_hooks
from .shige_pop.popup_config import set_gui_hook_change_log

set_PB_hooks()
setup_config_hooks()
set_gui_hook_change_log()

