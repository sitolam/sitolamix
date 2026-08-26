

import datetime
import math
from aqt import QAbstractItemView, QIcon, QImage, QPixmap, QSize, QSizePolicy, QTabWidget, QTableWidgetItem, QTimer, Qt, mw, QTableWidget, QHeaderView

from ..config_manager import write_config
from ..custom_shige.path_manager import (
    TIME_FLAT_ICON_LIGHT, TIME_FLAT_ICON_DARK, WEATHER_ICON, WEATHER_ICON_DARK, TREE_ICON,
    LIFEBAR_ICON, ORB_ICON, XPBAR_ICON
    )

from .resize_icon import change_icon_size

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .build_bord_v2 import RebuildLeaderbord

IS_HIDE_BY_REVIEW_SECONDS = False
HIDE_THRESHOLD = 2

IS_ARART_BY_REVIEW_SECONDS = True
ARART_THRESHOLD = 2

is_mini_mode = False

#MARK:QtableItem
### Custom sort for QtableItem  ####
# https://stackoverflow.com/a/48509443
class UserRoleQTableItem(QTableWidgetItem):
    def __lt__(self, other):
        user_role_self = self.data(Qt.ItemDataRole.UserRole)
        user_role_other = other.data(Qt.ItemDataRole.UserRole)
        if user_role_self is None or user_role_other is None:
            return super().__lt__(other)
        return user_role_self < user_role_other

def make_new_item(ori_text, di_text, item:"QTableWidgetItem", tab:"QTableWidget", row, column, align_right=False):
    ori_text_str = str(ori_text)
    new_item = UserRoleQTableItem(ori_text_str)
    new_item.setData(Qt.ItemDataRole.UserRole, ori_text)
    new_item.setData(Qt.ItemDataRole.DisplayRole, di_text)
    new_item.setForeground(item.foreground())
    new_item.setBackground(item.background())
    new_item.setFont(item.font())
    new_item.setTextAlignment(item.textAlignment())
    new_item.setToolTip(item.toolTip())
    if align_right == "right":
        align_right = Qt.AlignmentFlag.AlignRight
    elif align_right == "center":
        align_right = Qt.AlignmentFlag.AlignCenter
    else:
        align_right = Qt.AlignmentFlag.AlignLeft

    new_item.setTextAlignment(align_right| Qt.AlignmentFlag.AlignVCenter)
    if item.icon() and not item.icon().isNull():
        new_item.setIcon(item.icon())
    tab.setItem(row, column, new_item)


#MARK: time
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
            # Skip already updated
            if item.data(Qt.ItemDataRole.UserRole) is not None:
                continue

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
                    if league_days <= 0:
                        league_days = 1
                    else:
                        league_days = league_days

                    league_minutes = int(max(0, minutes // league_days))
                    # league_hours = int(max(0, hours // league_days))
                    # league_miniutes = int(max(0, remaining_minutes // league_days))
                    league_hours = int(max(0, league_minutes // 60))
                    league_miniutes = int(max(0, league_minutes % 60))
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

                    resize_icon = change_icon_size(time_icon_cache[icon_path], column_index)
                    item.setIcon(resize_icon)

                    # item.setIcon(QIcon(icon_path))

                if not league_days == None:
                    if is_mini_mode:
                        display_text = f"{league_hours:02}h {league_miniutes:02}m/d"
                        # display_text = f"{league_hours:02}:{league_miniutes:02}/d"
                    else:
                        display_text = f"{league_hours:02}h {league_miniutes:02}m /d ({hours:02}h {remaining_minutes:02}m)"
                        # display_text = f"{league_hours:02}:{league_miniutes:02} /d ({hours:02}:{remaining_minutes:02})"
                else:
                    display_text = f"{hours:02}h {remaining_minutes:02}m"
                    # display_text = f"{hours:02}:{remaining_minutes:02}"

                # display_text = f"{hours:02}:{remaining_minutes:02}{time_emoji}"
                make_new_item(original_text, display_text, item, tab_widget, row, column_index)


#MARK:streaks
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
            # Skip already updated
            if item.data(Qt.ItemDataRole.UserRole) is not None:
                continue

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

                if is_mini_mode:
                    all_days_text = f"{int(original_text):,}d"
                    display_text = f"{all_days_text}"
                else:
                    display_text = f"{years_text}{months_text}{remaining_days_text}{all_days_text}{streaks_emoji}"

                icon_path = get_tree_icon(days)
                if icon_path:
                    if icon_path not in tree_icon_cache:
                        tree_icon_cache[icon_path] = QIcon(icon_path)
                    resize_icon = change_icon_size(tree_icon_cache[icon_path], column_index)
                    item.setIcon(resize_icon)

                make_new_item(original_text, display_text, item, tab_widget, row, column_index, align_right="center")

#####################


#MARK: past 31 days

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
            # Skip already updated
            if item.data(Qt.ItemDataRole.UserRole) is not None:
                continue

            # original_text = item.data(Qt.ItemDataRole.DisplayRole)
            if item.data(Qt.ItemDataRole.UserRole):
                original_text = item.data(Qt.ItemDataRole.UserRole)
            else:
                original_text = item.data(Qt.ItemDataRole.DisplayRole)

            if original_text:
                cards_31day = int(float(original_text))
                perday = max(0, cards_31day // 31)

                if is_mini_mode:
                    display_text = f"{int(perday):,}/d"
                else:
                    display_text = f"{int(perday):,} /d ({int(cards_31day):,} rev)"

                icon_path =  get_orb_icon(int(perday))
                if icon_path:
                    if icon_path not in orb_icon_cache:
                        orb_icon_cache[icon_path] = QIcon(icon_path)
                    resize_icon = change_icon_size(orb_icon_cache[icon_path], column_index)
                    item.setIcon(resize_icon)

                make_new_item(original_text, display_text, item, tab_widget, row, column_index, align_right="right")

#MARK: League Review

def update_display_text_league_review(tab_widget: "QTableWidget", column_index, time_column, league_days):
    orb_icon_cache = {}
    for row in range(tab_widget.rowCount()):
        item = tab_widget.item(row, column_index)
        if item:
            # Skip already updated
            if item.data(Qt.ItemDataRole.UserRole) is not None:
                continue

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

                            if is_mini_mode:
                                display_text = f"{int(perday):,}/d ({second_per_card}s)"
                            else:
                                display_text = f"{int(perday):,} /d ({alert_emoji}{second_per_card}" + f"sec {int(cards_14day):,} rev)"

                            icon_path =  get_orb_icon(int(perday))
                            if icon_path:
                                if icon_path not in orb_icon_cache:
                                    orb_icon_cache[icon_path] = QIcon(icon_path)

                                resize_icon = change_icon_size(orb_icon_cache[icon_path], column_index)
                                item.setIcon(resize_icon)

                            make_new_item(original_text, display_text, item, tab_widget, row, column_index, align_right="right")




#MARK: Retention

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
            # Skip already updated
            if item.data(Qt.ItemDataRole.UserRole) is not None:
                continue

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

                    resize_icon = change_icon_size(weather_icon_cache[icon_path], column_index)
                    item.setIcon(resize_icon)

                display_text = f"{int(original_text)}%"
                make_new_item(original_text, display_text, item, tab_widget, row, column_index)


#MARK: review
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
            # Skip already updated
            if item.data(Qt.ItemDataRole.UserRole) is not None:
                continue

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
                            if is_mini_mode:
                                display_text = f"{review:,} (0s)"
                            else:
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

                                    resize_icon = change_icon_size(lifebar_icon_chash[icon_path], column_index)
                                    item.setIcon(resize_icon)

                            second_per_card = round(max(0, second // review))
                            alert_emoji = ""
                            if (IS_ARART_BY_REVIEW_SECONDS
                                and second_per_card <= ARART_THRESHOLD
                                and review > 100):
                                alert_emoji = "🚨"

                            if is_mini_mode:
                                display_text = f"{review:,} ({second_per_card}s)"
                            else:
                                display_text = f"{review:,} rev ({alert_emoji}{second_per_card}" + f"sec){day31_text}"

                        make_new_item(original_text, display_text, item, tab_widget, row, column_index, align_right="left")

                        if IS_HIDE_BY_REVIEW_SECONDS:
                            if second_per_card < HIDE_THRESHOLD:
                                tab_widget.setRowHidden(row, True)
                            else:
                                tab_widget.setRowHidden(row, False)


#MARK: XP
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
            # Skip already updated
            if item.data(Qt.ItemDataRole.UserRole) is not None:
                continue

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

                    resize_icon = change_icon_size(xp_icon_cache[icon_path], column_index)
                    item.setIcon(resize_icon)

                if is_mini_mode:
                    display_text = f"Lv. {level}"
                else:
                    display_text = f"Lv. {level} ({display_text:,} xp)"
                make_new_item(original_text, display_text, item, tab_widget, row, column_index, align_right=True)


#MARK: main
def custom_column_size(rebuildboard:"RebuildLeaderbord" , table_widget:"QTableWidget"):
    global is_mini_mode

    config = mw.addonManager.getConfig(__name__)
    is_mini_mode = config.get("mini_mode", False)

    is_league = False
    if table_widget == rebuildboard.League_Leaderboard:
        is_league = True

    rebuildboard.Global_Leaderboard
    rebuildboard.Friends_Leaderboard
    rebuildboard.Country_Leaderboard
    rebuildboard.Custom_Leaderboard
    rebuildboard.League_Leaderboard

    if not is_mini_mode:
        total_rows = rebuildboard.total_rows
        header_item = table_widget.horizontalHeaderItem(0)
        if header_item:
            header_item.setText(f"{total_rows}")

    if not is_league:
        update_display_review(table_widget, 2, 3, 5)
        update_display_text_time(table_widget, 3)
        update_display_text_streaks(table_widget, 4)
        update_display_text_31days(table_widget, 5)
        update_display_retention(table_widget, 6)
    else:
        league_days = max(0, min(14, ((datetime.datetime.now() - rebuildboard.season_start).days) +1 ))
        update_display_text_league_review(table_widget, 4, 3, league_days)

        update_display_XP(table_widget, 2)
        update_display_text_time(table_widget, 3, league_days)
        update_display_retention(table_widget, 5)
        update_display_retention(table_widget, 6)






    # header = table_widget.horizontalHeader()

    # resizeMode = QHeaderView.ResizeMode.ResizeToContents

    # header.setSectionResizeMode(0, resizeMode)

    # header.setSectionResizeMode(1, resizeMode)

    # header.setSectionResizeMode(2, resizeMode)
    # header.setSectionResizeMode(3, resizeMode)
    # header.setSectionResizeMode(4, resizeMode)
    # header.setSectionResizeMode(5, resizeMode)
    # header.setSectionResizeMode(6, resizeMode)

    # header.setSectionResizeMode(7, resizeMode)

    # header.setSectionResizeMode(8, QHeaderView.ResizeMode.Stretch)


    # # EnsureVisible
    # # PositionAtTop
    # # PositionAtBottom
    # # PositionAtCenter
    # if not current_page == 1:
    #     target_item = table_widget.item(10, 0)
    #     table_widget.scrollToItem(target_item, hint=QAbstractItemView.ScrollHint.PositionAtTop)



# ### main ###
# def custom_column_size(rebuildboard:"RebuildLeaderbord" , table_widget:"QTableWidget"):
#     global is_mini_mode

#     config = mw.addonManager.getConfig(__name__)
#     is_mini_mode = config.get("mini_mode", False)

#     is_league = False
#     if table_widget == rebuildboard.League_Leaderboard:
#         is_league = True

#     rebuildboard.Global_Leaderboard
#     rebuildboard.Friends_Leaderboard
#     rebuildboard.Country_Leaderboard
#     rebuildboard.Custom_Leaderboard
#     rebuildboard.League_Leaderboard

#     # total_rows = tab_widget.rowCount()
#     total_rows = rebuildboard.total_rows
#     header_item = table_widget.horizontalHeaderItem(0)
#     if header_item:
#         header_item.setText(f"{total_rows}")

#     if not is_league:
#         update_display_review(table_widget, 2, 3, 5)
#         update_display_text_time(table_widget, 3)
#         update_display_text_streaks(table_widget, 4)
#         update_display_text_31days(table_widget, 5)
#         update_display_retention(table_widget, 6)
#     else:
#         league_days = max(0, min(14, ((datetime.datetime.now() - rebuildboard.season_start).days) +1 ))
#         update_display_text_league_review(table_widget, 4, 3, league_days)

#         update_display_XP(table_widget, 2)
#         update_display_text_time(table_widget, 3, league_days)
#         update_display_retention(table_widget, 5)
#         update_display_retention(table_widget, 6)


#     def custom_colum_order(tab_widget:"QTableWidget"):
#         tab_widget.horizontalHeader().setSectionsMovable(True)

#         def set_column_order(tab_widget:"QTableWidget", order):

#             for index, target_index in enumerate(order):
#                 now_index = tab_widget.horizontalHeader().visualIndex(index)
#                 if now_index != target_index:
#                     tab_widget.horizontalHeader().moveSection(now_index, target_index)

#         desired_order = [1, 2, 3, 4, 5, 6, 7, 0, 8]
#         set_column_order(tab_widget, desired_order)
#         tab_widget.horizontalHeader().setSectionsMovable(False)
#     custom_colum_order(table_widget)

#     # [1, 2, 3, 4, 6, 7, 5, 0, 8]
#     # [1, 2, 3, 4, 5, 6, 7, 0, 8]

#     test_func = False
#     if test_func:
#         def save_column_widths(tab_widget:"QTableWidget"):
#             column_widths = [tab_widget.columnWidth(i) for i in range(tab_widget.columnCount())]
#             write_config("column_widths", column_widths)

#         def save_column_order(tab_widget:"QTableWidget"):
#             column_order = [tab_widget.horizontalHeader().visualIndex(i) for i in range(tab_widget.columnCount())]
#             write_config("desired_order", column_order)

#         if table_widget == rebuildboard.Global_Leaderboard or is_league:
#             table_widget.horizontalHeader().sectionMoved.connect(lambda: save_column_order(table_widget))
#             table_widget.horizontalHeader().sectionResized.connect(lambda: save_column_widths(table_widget))