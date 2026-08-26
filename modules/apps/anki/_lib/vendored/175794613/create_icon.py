

from os.path import  join, dirname
from typing import Literal

from aqt import mw, QIcon

class QIconWithPath(QIcon):
    def __init__(self, path):
        super().__init__(path)
        self._path = path

    def set_path(self, path):
        self._path = path

    def get_path(self):
        return self._path

def create_leaderboard_icon(
                        file_name: str,
                        icon_type: Literal["shield", "flag", "other", "hexagon", "diamond" ] = "",
                        is_need_only_path = False
                        ):

    if not hasattr(mw, 'leaderbord_icon_cache'):
        mw.leaderbord_icon_cache = {}

    addon_path = dirname(__file__)

    save_file_path = f"{icon_type}_{file_name}"

    if not is_need_only_path:
        if save_file_path in mw.leaderbord_icon_cache:
            return mw.leaderbord_icon_cache[save_file_path]

    if icon_type == "other" :
        icon_path = join(addon_path, "media_files", "others", file_name)

    elif icon_type == "flag" :
        icon_path = join(addon_path, "media_files", "country", file_name)

    elif icon_type == "shield" :
        icon_path = join(addon_path, "media_files", "league_shields", file_name)

    elif icon_type == "hexagon" :
        icon_path = join(addon_path, "media_files", "global_hexagon", file_name)

    elif icon_type == "diamond" :
        icon_path = join(addon_path, "media_files", "global_diamond", file_name)

    else:
        icon_path = join(addon_path, "media_files", file_name)

    if is_need_only_path:
        return icon_path

    icon = QIconWithPath(icon_path)

    mw.leaderbord_icon_cache[save_file_path] = icon
    return icon






# pixmap = QPixmap(join(addon_path, "custom_shige", "flags", file_name))
# rounded_pixmap = QPixmap(pixmap.size())
# rounded_pixmap.fill(Qt.GlobalColor.transparent)

# painter = QPainter(rounded_pixmap)
# painter.setRenderHint(QPainter.RenderHint.Antialiasing)
# painter.setBrush(QBrush(pixmap))
# painter.drawEllipse(0, 0, pixmap.width(), pixmap.height())
# painter.end()
# icon = QIconWithPath(rounded_pixmap)
# icon.set_path(join(addon_path, "custom_shige", "flags", file_name))