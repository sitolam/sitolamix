

import datetime
import math
from aqt import QIcon, QImage, QPixmap, QSize, QSizePolicy, QTabWidget, QTableWidgetItem, QTimer, Qt, mw, QTableWidget, QHeaderView

from .config_manager import write_config
from .custom_shige.path_manager import (
    TIME_FLAT_ICON_LIGHT, TIME_FLAT_ICON_DARK, WEATHER_ICON, WEATHER_ICON_DARK, TREE_ICON,
    LIFEBAR_ICON, ORB_ICON, XPBAR_ICON
    )

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from Leaderboard import start_main


IS_HIDE_BY_REVIEW_SECONDS = False
HIDE_THRESHOLD = 2

IS_ARART_BY_REVIEW_SECONDS = True
ARART_THRESHOLD = 2

IS_EMOJI = True

### Custom sort for QtableItem  ####
# https://stackoverflow.com/a/48509443
class UserRoleQTableItem(QTableWidgetItem):
    def __lt__(self, other):
        user_role_self = self.data(Qt.ItemDataRole.UserRole)
        user_role_other = other.data(Qt.ItemDataRole.UserRole)
        if user_role_self is None or user_role_other is None:
            return super().__lt__(other)
        return user_role_self < user_role_other

def make_new_item(ori_text, di_text, item:"QTableWidgetItem", tab:"QTableWidget", row, column):
    ori_text_str = str(ori_text)
    new_item = UserRoleQTableItem(ori_text_str)
    new_item.setData(Qt.ItemDataRole.UserRole, ori_text)
    new_item.setData(Qt.ItemDataRole.DisplayRole, di_text)
    new_item.setForeground(item.foreground())
    new_item.setBackground(item.background())
    new_item.setFont(item.font())
    new_item.setTextAlignment(item.textAlignment())
    new_item.setToolTip(item.toolTip())
    new_item.setTextAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
    if item.icon() and not item.icon().isNull():
        new_item.setIcon(item.icon())
    tab.setItem(row, column, new_item)


### time ###
def get_time_icon(time_value):
    time_value = int(time_value)
    numeric_keys = sorted([int(key) for key in TIME_FLAT_ICON_LIGHT.keys()])
    selected_key = str(numeric_keys[0])
    for key in numeric_keys:
        if key <= time_value:
            selected_key = str(key)
        else:
            break
    try:
        from aqt.theme import theme_manager
        if theme_manager.night_mode:
            result = TIME_FLAT_ICON_LIGHT.get(selected_key, None)
        else:
            result = TIME_FLAT_ICON_DARK.get(selected_key, None)
    except Exception as e:
        print("Leadearboard Error get_time_icon: ",e)
        result = TIME_FLAT_ICON_LIGHT.get(selected_key, None)
    return result


def update_display_text_time(tab_widget:"QTableWidget", column_index, league_days=None):
    time_icon_cache = {}
    for row in range(tab_widget.rowCount()):
        item = tab_widget.item(row, column_index)
        if item:
            # original_text = item.data(Qt.ItemDataRole.DisplayRole)
            if item.data(Qt.ItemDataRole.UserRole):
                original_text = item.data(Qt.ItemDataRole.UserRole)
            else:
                original_text = item.data(Qt.ItemDataRole.DisplayRole)

            if original_text:
                minutes = int(float(original_text))
                hours = minutes // 60
                remaining_minutes = minutes % 60

                if not league_days == None:
                    league_days = 1 if league_days <= 0  else league_days
                    league_minutes = int(max(0, minutes // league_days))
                    league_hours = int(max(0, hours // league_days))
                    league_miniutes = int(max(0, remaining_minutes // league_days))
                    icon_time = league_minutes
                else:
                    icon_time = minutes

                # time_emoji = ""
                # if minutes >= 60:
                    # fire_count = minutes // 60
                    # time_emoji = "🔥" * fire_count
                icon_path =  get_time_icon(icon_time)
                if icon_path:
                    if icon_path not in time_icon_cache:
                        time_icon_cache[icon_path] = QIcon(icon_path)

                    item.setIcon(time_icon_cache[icon_path])

                    # item.setIcon(QIcon(icon_path))

                if not league_days == None:
                    display_text = f"{league_hours:02}:{league_miniutes:02} /d ({hours:02}:{remaining_minutes:02})"
                else:
                    display_text = f"{hours:02}:{remaining_minutes:02}"
                # display_text = f"{hours:02}:{remaining_minutes:02}{time_emoji}"

                make_new_item(original_text, display_text, item, tab_widget, row, column_index)


### streaks ###

def get_tree_icon(streak):
    streak = int(streak)
    numeric_keys = sorted([int(key) for key in TREE_ICON.keys()])
    selected_key = str(numeric_keys[0])
    for key in numeric_keys:
        if key <= streak:
            selected_key = str(key)
        else:
            break
    result = TREE_ICON.get(selected_key, None)
    return result

def is_repeating_number(streak):
        s = str(streak)
        if len(s) >= 3:
            return all(c == s[0] for c in s)
        return False

def check_streaks(streak):
    if (streak != 0
        and (
        streak % 100 == 0
        or streak % 365 == 0
        or streak in [7, 31, 60]
        or is_repeating_number(streak))):
        return True


def update_display_text_streaks(tab_widget:"QTableWidget", column_index:int):
    tree_icon_cache = {}
    for row in range(tab_widget.rowCount()):
        item = tab_widget.item(row, column_index)
        if item:
            # original_text = item.data(Qt.ItemDataRole.DisplayRole)
            if item.data(Qt.ItemDataRole.UserRole):
                original_text = item.data(Qt.ItemDataRole.UserRole)
            else:
                original_text = item.data(Qt.ItemDataRole.DisplayRole)

            if original_text:
                days = int(float(original_text))

                years = days // 365
                remaining_days = days % 365
                months = 0
                for days_in_month in [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]:
                    if remaining_days >= days_in_month:
                        remaining_days -= days_in_month
                        months += 1
                    else:
                        break
                streaks_emoji = ""
                if days > 0 and days % 365 == 0:
                    streaks_emoji = "🍰"
                elif check_streaks(days):
                    streaks_emoji = "🎉"
                years_text = f"{years}y " if years else ""
                months_text = f"{months}m " if months else ""
                remaining_days_text = f"{remaining_days}d " if remaining_days else "0d "

                if not months and not years:
                    all_days_text = f"{int(original_text):,}d"
                    remaining_days_text = ""
                else:
                    all_days_text = f"({int(original_text):,}d)"

                display_text = f"{years_text}{months_text}{remaining_days_text}{all_days_text}{streaks_emoji}"

                icon_path =  get_tree_icon(days)
                if icon_path:
                    if icon_path not in tree_icon_cache:
                        tree_icon_cache[icon_path] = QIcon(icon_path)
                    item.setIcon(tree_icon_cache[icon_path])

                make_new_item(original_text, display_text, item, tab_widget, row, column_index)
#####################


### past 31 days ###

def get_orb_icon(cards_31day):
    cards_31day = int(cards_31day)
    numeric_keys = sorted([int(key) for key in ORB_ICON.keys()])
    selected_key = str(numeric_keys[0])
    for key in numeric_keys:
        if key <= cards_31day:
            selected_key = str(key)
        else:
            break
    result = ORB_ICON.get(selected_key, None)
    return result

def update_display_text_31days(tab_widget: "QTableWidget", column_index: int):
    orb_icon_cache = {}
    for row in range(tab_widget.rowCount()):
        item = tab_widget.item(row, column_index)
        if item:
            # original_text = item.data(Qt.ItemDataRole.DisplayRole)
            if item.data(Qt.ItemDataRole.UserRole):
                original_text = item.data(Qt.ItemDataRole.UserRole)
            else:
                original_text = item.data(Qt.ItemDataRole.DisplayRole)

            if original_text:
                cards_31day = int(float(original_text))
                perday = max(0, cards_31day // 31)
                display_text = f"{int(perday):,} /d ({int(cards_31day):,} rev )"
                # display_text = f"{int(cards_31day):,} rev ({int(perday):,}/d)"

                icon_path =  get_orb_icon(int(perday))
                if icon_path:
                    if icon_path not in orb_icon_cache:
                        orb_icon_cache[icon_path] = QIcon(icon_path)
                    item.setIcon(orb_icon_cache[icon_path])

                make_new_item(original_text, display_text, item, tab_widget, row, column_index)

### League Review ###

def update_display_text_league_review(tab_widget: "QTableWidget", column_index, time_column, league_days):
    orb_icon_cache = {}
    for row in range(tab_widget.rowCount()):
        item = tab_widget.item(row, column_index)
        if item:
            # original_text = item.data(Qt.ItemDataRole.DisplayRole)
            if item.data(Qt.ItemDataRole.UserRole):
                original_text = item.data(Qt.ItemDataRole.UserRole)
            else:
                original_text = item.data(Qt.ItemDataRole.DisplayRole)

            if original_text:
                item_time = tab_widget.item(row, time_column)

                # time
                if item_time:
                    if item_time.data(Qt.ItemDataRole.UserRole):
                        original_text_time = item_time.data(Qt.ItemDataRole.UserRole)
                    else:
                        original_text_time = item_time.data(Qt.ItemDataRole.DisplayRole)

                    if original_text_time:

                        second = float(original_text_time) * 60
                        review = int(float(original_text))
                        if review == 0:
                            display_text = f"{review:,} rev (0" + "sec)"
                        else:
                            second_per_card = round(max(0, second // review))
                            alert_emoji = ""
                            if (IS_ARART_BY_REVIEW_SECONDS
                                and second_per_card <= ARART_THRESHOLD
                                and review > 100):
                                alert_emoji = "🚨"
                            # display_text = f"{review:,} rev ({alert_emoji}{second_per_card}" + f"sec)"

                            cards_14day = int(float(original_text))
                            if league_days <= 0:
                                league_days = 1
                            perday = max(0, cards_14day // league_days)
                            display_text = f"{int(perday):,} /d ({alert_emoji}{second_per_card}" + f"sec, {int(cards_14day):,} rev )"
                            # display_text = f"{int(cards_31day):,} rev ({int(perday):,}/d)"

                            icon_path =  get_orb_icon(int(perday))
                            if icon_path:
                                if icon_path not in orb_icon_cache:
                                    orb_icon_cache[icon_path] = QIcon(icon_path)
                                item.setIcon(orb_icon_cache[icon_path])

                            make_new_item(original_text, display_text, item, tab_widget, row, column_index)




### Retention ###

# Retention Bonus:
# 85%-100% -> 100%
# 70%-84%  -> 85%
# 55%-69%  -> 70%
# 40%-54%  -> 55%
# 25%-39%  -> 40%
# 10%-24%  -> 25%
# 0%-9%   -> 0%

def get_weather_icon(retention_value):
    retention_value = int(float(retention_value))
    numeric_keys = sorted([int(key) for key in WEATHER_ICON.keys()])
    selected_key = str(numeric_keys[0])
    for key in numeric_keys:
        if key <= retention_value:
            selected_key = str(key)
        else:
            break
    try:
        from aqt.theme import theme_manager
        if theme_manager.night_mode:
            result = WEATHER_ICON_DARK.get(selected_key, None)
        else:
            result = WEATHER_ICON.get(selected_key, None)
    except Exception as e:
        print("Leadearboard Error get_time_icon: ",e)
        result = WEATHER_ICON.get(selected_key, None)
    return result


def update_display_retention(tab_widget:"QTableWidget", column_index:int):
    weather_icon_cache = {}
    for row in range(tab_widget.rowCount()):
        item = tab_widget.item(row, column_index)
        if item:
            # original_text = item.data(Qt.ItemDataRole.DisplayRole)
            if item.data(Qt.ItemDataRole.UserRole):
                original_text = item.data(Qt.ItemDataRole.UserRole)
            else:
                original_text = item.data(Qt.ItemDataRole.DisplayRole)

            if original_text:

                icon_path =  get_weather_icon(original_text)
                if icon_path:
                    if icon_path not in weather_icon_cache:
                        row_height = tab_widget.rowHeight(row)
                        icon_size = int(row_height * 0.5)
                        pixmap = QPixmap(icon_path)
                        scaled_pixmap = pixmap.scaled(
                            icon_size, icon_size,
                            Qt.AspectRatioMode.KeepAspectRatio,
                            Qt.TransformationMode.SmoothTransformation
                        )
                        weather_icon_cache[icon_path] = QIcon(scaled_pixmap)
                        # weather_icon_cache[icon_path] = QIcon(icon_path)
                    item.setIcon(weather_icon_cache[icon_path])

                display_text = f"{original_text}%"
                make_new_item(original_text, display_text, item, tab_widget, row, column_index)


### review ###
def get_lifebar_icon(review_value):
    review_value = int(float(review_value))
    numeric_keys = sorted([int(key) for key in LIFEBAR_ICON.keys()])
    selected_key = str(numeric_keys[0])
    for key in numeric_keys:
        if key <= review_value:
            selected_key = str(key)
        else:
            break
    return LIFEBAR_ICON.get(selected_key, None)
    # try:
    #     from aqt.theme import theme_manager
    #     if theme_manager.night_mode:
    #         result = WEATHER_ICON_DARK.get(selected_key, None)
    #     else:
    #         result = WEATHER_ICON.get(selected_key, None)
    # except Exception as e:
    #     print("Leadearboard Error get_time_icon: ",e)
    #     result = WEATHER_ICON.get(selected_key, None)


def update_display_review(tab_widget:"QTableWidget", column_index, time_column=3, day31_column=None):
    lifebar_icon_chash = {}
    for row in range(tab_widget.rowCount()):
        item = tab_widget.item(row, column_index)
        if item:
            # original_text = item.data(Qt.ItemDataRole.DisplayRole)
            if item.data(Qt.ItemDataRole.UserRole):
                original_text = item.data(Qt.ItemDataRole.UserRole)
            else:
                original_text = item.data(Qt.ItemDataRole.DisplayRole)

            if original_text:
                item_time = tab_widget.item(row, time_column)

                # day31
                perday = False
                if day31_column:
                    item_day31_column = tab_widget.item(row, day31_column)
                    if item_day31_column:
                        if item_day31_column.data(Qt.ItemDataRole.UserRole):
                            original_text_day31 = item_day31_column.data(Qt.ItemDataRole.UserRole)
                        else:
                            original_text_day31 = item_day31_column.data(Qt.ItemDataRole.DisplayRole)
                        cards_31day = int(float(original_text_day31))
                        perday = max(0, cards_31day // 31)

                # time
                if item_time:
                    if item_time.data(Qt.ItemDataRole.UserRole):
                        original_text_time = item_time.data(Qt.ItemDataRole.UserRole)
                    else:
                        original_text_time = item_time.data(Qt.ItemDataRole.DisplayRole)

                    if original_text_time:
                        review_completion_rate = 0

                        second = float(original_text_time) * 60
                        review = int(float(original_text))
                        if review == 0:
                            display_text = f"{review:,} rev (0" + "sec)"
                        else:
                            # day31
                            day31_text = ""
                            if not perday == False:
                                # if review > perday:
                                #     day31_text = "🔥"
                                review_completion_rate = int(max(0, min(100, (review/ perday) * 100))) if perday > 0 else 0
                                icon_path =  get_lifebar_icon(review_completion_rate)
                                if icon_path:
                                    if icon_path not in lifebar_icon_chash:
                                        # row_height = tab_widget.rowHeight(row)
                                        # icon_size = int(row_height * 0.8)
                                        # pixmap = QPixmap(icon_path)
                                        # scaled_pixmap = pixmap.scaled(
                                        #     icon_size, icon_size,
                                        #     Qt.AspectRatioMode.KeepAspectRatio,
                                        #     Qt.TransformationMode.SmoothTransformation
                                        # )
                                        lifebar_icon_chash[icon_path] = QIcon(icon_path)
                                        # LIFEBAR_ICON_CHASH[icon_path] = QIcon(icon_path)
                                    item.setIcon(lifebar_icon_chash[icon_path])

                            second_per_card = round(max(0, second // review))
                            alert_emoji = ""
                            if (IS_ARART_BY_REVIEW_SECONDS
                                and second_per_card <= ARART_THRESHOLD
                                and review > 100):
                                alert_emoji = "🚨"
                            display_text = f"{review:,} rev ({alert_emoji}{second_per_card}" + f"sec){day31_text}"

                        make_new_item(original_text, display_text, item, tab_widget, row, column_index)

                        if IS_HIDE_BY_REVIEW_SECONDS:
                            if second_per_card < HIDE_THRESHOLD:
                                tab_widget.setRowHidden(row, True)
                            else:
                                tab_widget.setRowHidden(row, False)


### XP ###
def get_level(exp):
    level = math.floor(math.sqrt(exp / 2000))
    next_lavel = get_percentage_to_next_level(exp)
    # print(f"Level: {level} ({next_lavel}%)")
    return level, next_lavel

def get_percentage_to_next_level(exp):
    current_level = math.floor(math.sqrt(exp / 2000))
    current_exp_needed = current_level ** 2 * 2000
    next_level_exp = (current_level + 1) ** 2 * 2000
    exp_needed_for_next = next_level_exp - current_exp_needed
    exp_progress = exp - current_exp_needed
    percent = (exp_progress / exp_needed_for_next) * 100
    return int(percent)

def get_xp_icon(level_value):
    level_value = int(float(level_value))
    numeric_keys = sorted([int(key) for key in XPBAR_ICON.keys()])
    selected_key = str(numeric_keys[0])
    for key in numeric_keys:
        if key <= level_value:
            selected_key = str(key)
        else:
            break
    result = XPBAR_ICON.get(selected_key, None)
    return result

def update_display_XP(tab_widget:"QTableWidget", column_index:int):
    xp_icon_cache = {}
    for row in range(tab_widget.rowCount()):
        item = tab_widget.item(row, column_index)
        if item:
            # original_text = item.data(Qt.ItemDataRole.DisplayRole)
            if item.data(Qt.ItemDataRole.UserRole):
                original_text = item.data(Qt.ItemDataRole.UserRole)
            else:
                original_text = item.data(Qt.ItemDataRole.DisplayRole)

            if original_text:
                display_text = int(float(original_text))
                
                level, next_lavel= get_level(display_text)

                icon_path =  get_xp_icon(next_lavel)
                if icon_path:
                    if icon_path not in xp_icon_cache:
                        xp_icon_cache[icon_path] = QIcon(icon_path)
                    item.setIcon(xp_icon_cache[icon_path])

                display_text = f"Lv. {level} ({display_text:,} xp)"
                make_new_item(original_text, display_text, item, tab_widget, row, column_index)


### main ###

def custom_column_size(start_main:"start_main" , tab_widget:"QTableWidget"):
    config = mw.addonManager.getConfig(__name__)


    is_league = False
    if tab_widget == start_main.dialog.League:
        is_league = True

    start_main.dialog.Global_Leaderboard
    start_main.dialog.Friends_Leaderboard
    start_main.dialog.Country_Leaderboard
    start_main.dialog.Custom_Leaderboard
    start_main.dialog.League

    total_rows = tab_widget.rowCount()
    header_item = tab_widget.horizontalHeaderItem(0)
    if header_item:
        header_item.setText(f"{total_rows}")

    header = tab_widget.horizontalHeader()

    # https://stackoverflow.com/a/12574002
    header.setSortIndicatorShown(False)


    if config.get("manually_customize_columns", False):
        if tab_widget == start_main.dialog.Global_Leaderboard:
            resizeMode = QHeaderView.ResizeMode.Interactive
        elif is_league:
            resizeMode = QHeaderView.ResizeMode.Fixed
        else:
            resizeMode = QHeaderView.ResizeMode.Fixed
    else:
        # resizeMode = QHeaderView.ResizeMode.ResizeToContents

        if tab_widget == start_main.dialog.Global_Leaderboard:
            resizeMode = QHeaderView.ResizeMode.ResizeToContents
        elif is_league:
            resizeMode = QHeaderView.ResizeMode.ResizeToContents
        else:
            resizeMode = QHeaderView.ResizeMode.Fixed

    # resizeMode = QHeaderView.ResizeMode.ResizeToContents

    header.setSectionResizeMode(0, resizeMode)

    header.setSectionResizeMode(1, resizeMode)

    header.setSectionResizeMode(2, resizeMode)
    header.setSectionResizeMode(3, resizeMode)
    header.setSectionResizeMode(4, resizeMode)
    header.setSectionResizeMode(5, resizeMode)
    header.setSectionResizeMode(6, resizeMode)

    header.setSectionResizeMode(7, resizeMode)
    # tab_widget.setColumnWidth(7, 50)
    # tab_widget.horizontalHeader().setSectionResizeMode(7, QHeaderView.ResizeMode.ResizeToContents)

    header.setSectionResizeMode(8, QHeaderView.ResizeMode.Stretch)
    # tab_widget.setColumnWidth(8, 25)
    # tab_widget.horizontalHeader().setSectionResizeMode(8, QHeaderView.ResizeMode.ResizeToContents)

    is_mini_text = config.get("mini_text", False)
    def set_minu_tezxt():
        for column_index in range(2, 7):
            header_item = tab_widget.horizontalHeaderItem(column_index)
            # tab_widget.horizontalHeader().setMinimumSectionSize(50)
            if header_item:
                text = header_item.text()

                if is_mini_text:
                    # ﾘｰｸﾞの設定がまだ
                    if column_index == 1:
                        if is_league:
                            text = "NAME"
                        else:
                            text = "NAME"
                    elif column_index == 2:
                        if is_league:
                            text = "XP"
                        else:
                            text = "REV"
                    elif column_index == 3:
                        if is_league:
                            text = "TIME"
                        else:
                            text = "TIME"
                    elif column_index == 4:
                        if is_league:
                            text = "REV"
                        else:
                            text = "STR"
                    elif column_index == 5:
                        if is_league:
                            text = "RE%"
                        else:
                            text = "31D"
                    elif column_index == 6:
                        if is_league:
                            text = "ST%"
                        else:
                            text = "RE%"
                    header_item.setText(text)

                    font_metrics = tab_widget.fontMetrics()
                    text_width = font_metrics.horizontalAdvance(text) + 30
                    if column_index == 1:
                        text_width += 50
                    tab_widget.setColumnWidth(column_index, text_width)

    if not is_league:
        update_display_review(tab_widget, 2, 3, 5)
        update_display_text_time(tab_widget, 3)
        update_display_text_streaks(tab_widget, 4)
        update_display_text_31days(tab_widget, 5)
        update_display_retention(tab_widget, 6)
        # update_display_league(tab_widget, 7)
    else:

        league_days = max(0, min(14, ((datetime.datetime.now() - start_main.season_start).days) +1 ))
        update_display_text_league_review(tab_widget, 4, 3, league_days)

        update_display_XP(tab_widget, 2)
        update_display_text_time(tab_widget, 3, league_days)
        # update_display_review(tab_widget, 4, 3)


        update_display_retention(tab_widget, 5)
        update_display_retention(tab_widget, 6)

    # default_column_widths = [60, 395, 184, 121, 224, 230, 111, 57, 57]

    # default_column_widths = [60, 395, 184, 121, 224, 230, 111]
    # for i, width in enumerate(default_column_widths):
    #     tab_widget.setColumnWidth(i, width)

    def set_colum_width():
        column_count = start_main.dialog.Global_Leaderboard.columnCount()
        for i in range(column_count):
            width = start_main.dialog.Global_Leaderboard.columnWidth(i)
            tab_widget.setColumnWidth(i, width)

        #     header_item = tab_widget.horizontalHeaderItem(i).text()
        #     print(f" {tab_widget.objectName()} : {i}.{header_item} : ", tab_widget.columnWidth(i))

        # print("")

        if is_league:
            header_g = start_main.dialog.Global_Leaderboard.horizontalHeader()
            # resizeMode_re = QHeaderView.ResizeMode.Interactive
            resizeMode_re = QHeaderView.ResizeMode.Fixed
            header_g.setSectionResizeMode(0, resizeMode_re)
            header_g.setSectionResizeMode(1, resizeMode_re)
            header_g.setSectionResizeMode(2, resizeMode_re)
            header_g.setSectionResizeMode(3, resizeMode_re)
            header_g.setSectionResizeMode(4, resizeMode_re)
            header_g.setSectionResizeMode(5, resizeMode_re)
            header_g.setSectionResizeMode(6, resizeMode_re)
            header_g.setSectionResizeMode(7,resizeMode_re)
            header_g.setSectionResizeMode(8, QHeaderView.ResizeMode.Stretch)

            header_l = start_main.dialog.League.horizontalHeader()
            # resizeMode_re = QHeaderView.ResizeMode.Interactive
            resizeMode_re = QHeaderView.ResizeMode.Fixed
            header_l.setSectionResizeMode(0, resizeMode_re)
            header_l.setSectionResizeMode(1, resizeMode_re)
            header_l.setSectionResizeMode(2, resizeMode_re)
            header_l.setSectionResizeMode(3, resizeMode_re)
            header_l.setSectionResizeMode(4, resizeMode_re)
            header_l.setSectionResizeMode(5, resizeMode_re)
            header_l.setSectionResizeMode(6, resizeMode_re)
            header_l.setSectionResizeMode(7,resizeMode_re)
            header_l.setSectionResizeMode(8, QHeaderView.ResizeMode.Stretch)

        
        # start_main.setContentsMargins(0, 0, 0, 0)
        # start_main.dialog.Parent.setContentsMargins(0, 0, 0, 0)
        # parent_tab =  tab_widget.parent() #type: QTabWidget
        # parent_tab.setContentsMargins(0, 0, 0, 0)
        # parent_tab.layout().setContentsMargins(0, 0, 0, 0)
        # # start_main.dialog.verticalLayout_5.setContentsMargins(0, 0, 0, 0)
        # tab_widget.setSizePolicy(QSizePolicy.Policy.Fixed, QSizePolicy.Policy.Preferred)
        

    QTimer.singleShot(0, set_colum_width)

    tab_widget.horizontalHeader().setSectionsMovable(True)

    def set_column_order(tab_widget:"QTableWidget", order):

        for index, target_index in enumerate(order):
            now_index = tab_widget.horizontalHeader().visualIndex(index)
            if now_index != target_index:
                tab_widget.horizontalHeader().moveSection(now_index, target_index)

    # desired_order = config.get("desired_order", None)
    # if not desired_order:
    desired_order = [1, 2, 3, 4, 5, 6, 7, 0, 8]
    set_column_order(tab_widget, desired_order)
    # QTimer.singleShot(0, lambda: set_column_order(tab_widget, desired_order))
    tab_widget.horizontalHeader().setSectionsMovable(False)

    # [1, 2, 3, 4, 6, 7, 5, 0, 8]
    # [1, 2, 3, 4, 5, 6, 7, 0, 8]

    test_func = False
    if test_func:
        def save_column_widths(tab_widget:"QTableWidget"):
            column_widths = [tab_widget.columnWidth(i) for i in range(tab_widget.columnCount())]
            write_config("column_widths", column_widths)

        def save_column_order(tab_widget:"QTableWidget"):
            column_order = [tab_widget.horizontalHeader().visualIndex(i) for i in range(tab_widget.columnCount())]
            write_config("desired_order", column_order)

        if tab_widget == start_main.dialog.Global_Leaderboard or is_league:
            tab_widget.horizontalHeader().sectionMoved.connect(lambda: save_column_order(tab_widget))
            tab_widget.horizontalHeader().sectionResized.connect(lambda: save_column_widths(tab_widget))

    

    # def set_colum_width_01():
    #     column_count = start_main.dialog.Global_Leaderboard.columnCount()
    #     for i in range(column_count):
    #         width = start_main.dialog.Global_Leaderboard.columnWidth(i)

    #         print(i, " : ",width)
    #         tab_widget.setColumnWidth(i, width)

    #     if is_league:
    #         header_g = start_main.dialog.Global_Leaderboard.horizontalHeader()
    #         resizeMode_re = QHeaderView.ResizeMode.Interactive
    #         header_g.setSectionResizeMode(0, resizeMode_re)
    #         header_g.setSectionResizeMode(1, resizeMode_re)
    #         header_g.setSectionResizeMode(2, resizeMode_re)
    #         header_g.setSectionResizeMode(3, resizeMode_re)
    #         header_g.setSectionResizeMode(4, resizeMode_re)
    #         header_g.setSectionResizeMode(5, resizeMode_re)
    #         header_g.setSectionResizeMode(6, resizeMode_re)
    #         header_g.setSectionResizeMode(7,resizeMode_re)
    #         header_g.setSectionResizeMode(8, QHeaderView.ResizeMode.Stretch)

    #         header_l = start_main.dialog.League.horizontalHeader()
    #         resizeMode_re = QHeaderView.ResizeMode.Interactive
    #         header_l.setSectionResizeMode(0, resizeMode_re)
    #         header_l.setSectionResizeMode(1, resizeMode_re)
    #         header_l.setSectionResizeMode(2, resizeMode_re)
    #         header_l.setSectionResizeMode(3, resizeMode_re)
    #         header_l.setSectionResizeMode(4, resizeMode_re)
    #         header_l.setSectionResizeMode(5, resizeMode_re)
    #         header_l.setSectionResizeMode(6, resizeMode_re)
    #         header_l.setSectionResizeMode(7,resizeMode_re)
    #         header_l.setSectionResizeMode(8, QHeaderView.ResizeMode.Stretch)

    

            # def inspect_column_properties(tab_widget:QTableWidget):
            #     header = tab_widget.horizontalHeader()
            #     column_to_check = 7

            #     print(tab_widget.objectName())
            #     print(f"列 {column_to_check} の情報:")
            #     print(f"  幅: {tab_widget.columnWidth(column_to_check)}px")
            #     print(f"  ﾘｻｲｽﾞﾓｰﾄﾞ: {header.sectionResizeMode(column_to_check)}")
            #     print(f"  最小ｻｲｽﾞ: {header.minimumSectionSize()}px")
            #     print(f"  ﾃﾞﾌｫﾙﾄｻｲｽﾞ: {header.defaultSectionSize()}px")
            #     print(f"  ｶｽｹｰﾄﾞﾘｻｲｽﾞ: {header.cascadingSectionResizes()}")
            #     print(f"  ｽﾄﾚｯﾁ最後のｾｸｼｮﾝ: {header.stretchLastSection()}")

            #     # ﾍｯﾀﾞｰｱｲﾃﾑの情報
            #     header_item = tab_widget.horizontalHeaderItem(column_to_check)
            #     if header_item:
            #         print(f"  ﾍｯﾀﾞｰﾃｷｽﾄ: '{header_item.text()}'")
            #         print(f"  ﾌｫﾝﾄ: {header_item.font().family()} {header_item.font().pointSize()}pt")
            #         print(f"  ｱｲｺﾝ: {'あり' if not header_item.icon().isNull() else 'なし'}")

            #     item1 = tab_widget.item(0, column_to_check)
            #     longest_text = ""
            #     longest_length = 0
            #     longest_row = -1
            #     for row in range(tab_widget.rowCount()):
            #         item = tab_widget.item(row, column_to_check)
            #         if item:
            #             display_text = item.data(Qt.ItemDataRole.DisplayRole)
            #             user_text = item.data(Qt.ItemDataRole.UserRole)
            #             if display_text and len(str(display_text)) > longest_length:
            #                 longest_text = str(display_text)
            #                 longest_length = len(longest_text)
            #                 longest_row = row
            #             if user_text and len(str(user_text)) > longest_length:
            #                 longest_text = str(user_text)
            #                 longest_length = len(longest_text)
            #                 longest_row = row

            #     print(f"列 {column_to_check} の最長ﾃｷｽﾄ (行 {longest_row}):")
            #     print(f"  ﾃｷｽﾄ: '{longest_text}'")
            #     print(f"  長さ: {longest_length} 文字")

            #     if longest_row >= 0:
            #         item = tab_widget.item(longest_row, column_to_check)
            #         font = item.font()
            #         print(f"  フォント: {font.family()} {font.pointSize()}pt {'太字' if font.bold() else '通常'}")



            # inspect_column_properties(start_main.dialog.Global_Leaderboard)
            # inspect_column_properties(start_main.dialog.League)

    

### display image ###
# https://forum.qt.io/topic/103084/add-qlabel-as-item-in-qtableview/2
# import os
# from aqt import QModelIndex, QPixmap, QStyleOptionViewItem, QStyledItemDelegate
# class ImageDelegate(QStyledItemDelegate):
#     def __init__(self, parent=None):
#         super().__init__(parent)
#     def paint(self, painter, option: QStyleOptionViewItem, index: QModelIndex):
#         addon_path = os.path.dirname(__file__)
#         image_path = os.path.join(addon_path, "shige_pop", "popup_icon.png")
#         # image_path = index.data(Qt.ItemDataRole.DisplayRole)
#         if image_path:
#             pixmap = QPixmap(image_path)
#             painter.drawPixmap(option.rect, pixmap)
#         else:
#             super().paint(painter, option, index)
# tab_widget.setItemDelegateForColumn(column_index, ImageDelegate(tab_widget))