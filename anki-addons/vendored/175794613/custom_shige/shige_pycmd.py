# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>


from aqt import mw, gui_hooks
from aqt.utils import tooltip

from ..config_manager import write_config
from ..path_manager import ADDON_NAME


try:
    from PyQt6.QtCore import QTimer
except:
    from aqt.qt import QTimer


#MARK:
def on_webview_did_receive_js_message(handled, message:str, context):
    try:

        if message.startswith("shige_leaderboard"):
            from .. import get_startup_shige_leaderboard

            if message == "shige_leaderboard":

                # QTimer.singleShot(100, get_startup_shige_leaderboard().leaderboard)
                QTimer.singleShot(100, get_startup_shige_leaderboard().rebuild_leaderboard)
                return (True, None)

            elif message == "shige_leaderboard_sync_and_update":
                QTimer.singleShot(100, get_startup_shige_leaderboard().startBackgroundSync)

                return (True, None)

            elif message == "shige_leaderboard_config":
                QTimer.singleShot(100, get_startup_shige_leaderboard().invokeSetup)

                return (True, None)

            elif message.startswith("shige_leaderboard_board_select:"):
                value = message.split(":", 1)[1]
                print(f"[{ADDON_NAME}] board_select: {value}")

                QTimer.singleShot(100, lambda:set_default_tab(value))

                return (True, None)

            elif message.startswith("shige_leaderboard_sort_select:"):

                value = message.split(":", 1)[1]
                print(f"[{ADDON_NAME}] sort_select: {value}")
                QTimer.singleShot(100, lambda:set_sort_by(value))

                return (True, None)

            elif message.startswith("shige_leaderboard_mode_select:"):
                value = message.split(":", 1)[1]
                print(f"[{ADDON_NAME}] mode_select: {value}")

                QTimer.singleShot(100, lambda:set_lb_home_mode(value))

                return (True, None)

            elif message == "shige_leaderboard_need_deckBrowser_refresh":
                def on_refresh_deckbrowser():
                    try:
                        from aqt import mw
                        if mw.state == "deckBrowser":
                            mw.deckBrowser.refresh()
                    except Exception as e:
                        print(f"[{ADDON_NAME}] Error: {e} ")

                QTimer.singleShot(100, on_refresh_deckbrowser)

                return (True, None)

            elif message.startswith("shige_leaderboard_select_group:"):
                key_index = message.split(":", 1)[1]
                QTimer.singleShot(100, lambda:get_group_name_by_index(key_index))

                return (True, None)

            elif message.startswith("shige_leaderboard_select_league:"):
                key_index = message.split(":", 1)[1]
                QTimer.singleShot(100, lambda:on_select_league(key_index))

                return (True, None)


            elif message == "shige_leaderboard_search_friends":
                QTimer.singleShot(100, on_search_friend)

                return (True, None)

            elif message == "shige_leaderboard_search_group":
                QTimer.singleShot(100, on_search_group)

                return (True, None)


            elif message == "shige_leaderboard_search_country":
                QTimer.singleShot(100, on_search_country)

                return (True, None)


            elif message.startswith("shige_leaderboard_select_country:"):
                key_index = message.split(":", 1)[1]
                QTimer.singleShot(100, lambda:on_select_country(key_index))

                return (True, None)


            elif message.startswith("shige_leaderboard_page:"):
                key_index = message.split(":", 1)[1]
                QTimer.singleShot(100, lambda:get_select_page(key_index))

                return (True, None)


            elif message.startswith("shige_leaderboard_select_max_row:"):
                key_index = message.split(":", 1)[1]
                QTimer.singleShot(100, lambda:on_select_max_row(key_index))

                return (True, None)


            elif message.startswith("shige_leaderboard_page_skip:"):
                key_index = message.split(":", 1)[1]
                QTimer.singleShot(100,
                        lambda:get_select_page(
                                    str_select_page="skip",
                                    int_value=key_index))

                return (True, None)


            elif message.startswith("shige_leaderboard_sync_info_tooltip:"):
                value = message.split(":", 1)[1]
                from ..lb_home_v2.now_loading_checker import on_sync_info_tooltip
                QTimer.singleShot(100,
                        lambda:on_sync_info_tooltip(value))

                return (True, None)


            elif message.startswith("shige_leaderboard_show_home_checkbox:"):
                value = message.split(":", 1)[1]
                QTimer.singleShot(100,
                        lambda:on_toggle_show_home(value))

                return (True, None)

            elif message.startswith("shige_leaderboard_toggle_autosync:"):
                value = message.split(":", 1)[1]
                QTimer.singleShot(100,
                        lambda:on_toggle_autosync(value))

                return (True, None)

            elif message.startswith("shige_leaderboard_show_buttons_checkbox:"):
                value = message.split(":", 1)[1]
                QTimer.singleShot(100,
                        lambda:on_toggle_show_home_buttons(value))

                return (True, None)

            elif message.startswith("shige_leaderboard_start_yesterday_checkbox:"):
                value = message.split(":", 1)[1]
                QTimer.singleShot(100,
                        lambda:on_toggle_start_yesterday(value))

                return (True, None)

            elif message.startswith("shige_leaderboard_discord_button_checkbox:"):
                value = message.split(":", 1)[1]
                QTimer.singleShot(100,
                        lambda:on_toggle_discord_button(value))

                return (True, None)


            elif message == "shige_leaderboard_sync_or_join":
                config = mw.addonManager.getConfig(__name__)
                if config["username"] == "" or not config["authToken"]:
                    QTimer.singleShot(100, get_startup_shige_leaderboard().invokeSetup)
                else:
                    QTimer.singleShot(100, get_startup_shige_leaderboard().startBackgroundSync)

                return (True, None)



            else:
                print(f"[{ADDON_NAME}] Not found: {message}")
                return (True, None)

        else:
            return handled

    except Exception as e:
        print(f"[{ADDON_NAME}] Error pycmd: {e} ")
        return handled


#MARK:home-sort
def set_sort_by(sortby):
    try:

        config = mw.addonManager.getConfig(__name__)

        if sortby == "Reviews":
            write_config("sortby", "Cards")
        elif sortby == "Time":
            write_config("sortby", "Time_Spend")
        elif sortby == "Streak":
            write_config("sortby", sortby)
        elif sortby == "31days":
            write_config("sortby", "Month")
        elif sortby == "Retention":
            write_config("sortby", sortby)

        if config["homescreen"] == True:
            write_config("homescreen_data", [])

            try:
                from ..config_local import get_local_config, save_local_config
                lo_config = get_local_config()
                lo_config["manually_user_index"] = None
                save_local_config(lo_config)
            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e}")

            try:
                from ..lb_on_homescreen import re_sort_leaderboard_data, refresh_home_board
                re_sort_leaderboard_data(sort_type=sortby)
                refresh_home_board()

            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e}")

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

    # tooltip("Changes will apply after the next sync!")



#MARK:home-tab
def set_default_tab(tab):
    try:
        config = mw.addonManager.getConfig(__name__)

        if tab == "Global":
            write_config("tab", 0)
        elif tab == "Friends":
            write_config("tab", 1)
        elif tab == "Country":
            write_config("tab", 2)
        elif tab == "Group":
            write_config("tab", 3)
        elif tab == "League":
            write_config("tab", 4)

        if config["homescreen"] == True:
            write_config("homescreen_data", [])
        # tooltip("Changes will apply after reloading the Home!")

        if mw.state == "deckBrowser":
            # mw.deckBrowser.refresh()
            try:
                from ..lb_on_homescreen import refresh_home_board
                refresh_home_board()
            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e}")

            delete_lo_conf_cache()

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

#MARK:home-mode
def set_lb_home_mode(mode):
    try:
        if not mode in ["Legacy", "Game", "G-Mini"]:
            return

        from ..config_local import get_local_config, save_local_config
        lo_config = get_local_config()
        lo_config["lb_home_mode"] = mode
        lo_config["manually_user_index"] = None
        save_local_config(lo_config)
        # tooltip("Changes will apply after reloading the Home!")

        config = mw.addonManager.getConfig(__name__)
        if config["homescreen"] == True:
            write_config("homescreen_data", [])

        if mw.state == "deckBrowser":
            try:
                from ..lb_on_homescreen import refresh_home_board
                refresh_home_board()
            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e}")
            # mw.deckBrowser.refresh()

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

#MARK:home-group
def get_group_name_by_index(key_index):
    try:
        key_index = int(key_index)
    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")
        return

    try:

        config = mw.addonManager.getConfig(__name__)
        groups = config.get("groups", [])
        if 0 <= key_index < len(groups):
            selected_group = groups[key_index]
            if selected_group:
                write_config("current_group", selected_group)
                print(f"[{ADDON_NAME}] current_group updated!")

                if config["homescreen"] == True:
                    write_config("homescreen_data", [])

                try:
                    from ..config_local import get_local_config, save_local_config
                    lo_config = get_local_config()
                    lo_config["manually_user_index"] = None
                    save_local_config(lo_config)
                except Exception as e:
                    print(f"[{ADDON_NAME}] Error: {e}")


                if mw.state == "deckBrowser":
                    # mw.deckBrowser.refresh()
                    try:
                        from ..lb_on_homescreen import refresh_home_board
                        refresh_home_board()
                    except Exception as e:
                        print(f"[{ADDON_NAME}] Error: {e}")

                return

        print(f"[{ADDON_NAME}] Error: current_group {key_index} not saved")

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

#MARK:ho-se-league
def on_select_league(league_name):
    try:
        league_names = ["Alpha", "Beta", "Gamma", "Delta"]
        if league_name not in league_names:
            print(f"[{ADDON_NAME}] Not found {league_name}")
            return

        from ..config_local import get_local_config, save_local_config
        lo_config = get_local_config()
        lo_config["home_selected_league"] = league_name
        lo_config["manually_user_index"] = None
        save_local_config(lo_config)

        config = mw.addonManager.getConfig(__name__)
        if config["homescreen"] == True:
            write_config("homescreen_data", [])

        if mw.state == "deckBrowser":
            try:
                from ..lb_on_homescreen import refresh_home_board
                refresh_home_board()
            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e}")

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

#MARK:on friend
def on_search_friend():
    try:
        from ..config_search_friends import SearchFriendWindow
        search_window = SearchFriendWindow(mw)
        search_window.exec()
        write_config("homescreen_data", [])
        if mw.state == "deckBrowser":
            try:
                from ..lb_on_homescreen import refresh_home_board
                refresh_home_board()
            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e}")

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")



#MARK:on group
def on_search_group():
    try:
        from ..config_search_group import SearchGroupWindow
        search_window = SearchGroupWindow(mw)
        search_window.exec()
        write_config("homescreen_data", [])
        if mw.state == "deckBrowser":
            try:
                from ..lb_on_homescreen import refresh_home_board
                refresh_home_board()
            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e}")

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

#MARK:on country
def on_search_country():
    try:
        from ..config_set_country import SetCountryWindow
        search_window = SetCountryWindow(mw)
        search_window.exec()
        write_config("homescreen_data", [])
        if mw.state == "deckBrowser":
            try:
                from ..lb_on_homescreen import refresh_home_board
                refresh_home_board()
            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e}")

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

def on_select_country(country_name):
    try:
        from ..custom_shige.country_dict import COUNTRY_LIST_V2

        if not country_name in COUNTRY_LIST_V2.keys():
            print(f"[{ADDON_NAME}] Not found {country_name}")
            return

        from ..config_local import get_local_config, save_local_config
        lo_config = get_local_config()
        lo_config["home_selected_country"] = country_name
        save_local_config(lo_config)

        config = mw.addonManager.getConfig(__name__)
        if config["homescreen"] == True:
            write_config("homescreen_data", [])

        if mw.state == "deckBrowser":
            try:
                from ..lb_on_homescreen import refresh_home_board
                refresh_home_board()
            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e}")
    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

#MARK:page
def get_select_page(str_select_page, int_value=None):
    try:
        from ..lb_on_homescreen import get_cache_board_data
        user_index, config_maxUsers, lb_length = get_cache_board_data().get("user_index", (None, None, None))
        if not user_index or not config_maxUsers:
            print(f"[{ADDON_NAME}] Error: get_select_page")
            return

        int_target_page = None

        if str_select_page == "top":
            int_target_page = 1

        elif str_select_page == "center":
            int_target_page = None

        elif str_select_page == "before":
            int_target_page = max(1, user_index - config_maxUsers)

        elif str_select_page == "next":
            int_target_page =  min(user_index + config_maxUsers, lb_length)

        elif str_select_page == "skip":
            int_value_int = int(int_value)
            int_target_page =  min(max(1, int_value_int), lb_length)

        else:
            print(f"[{ADDON_NAME}] page Error: {str_select_page} ")
            return

        from ..config_local import get_local_config, save_local_config
        lo_config = get_local_config()
        lo_config["manually_user_index"] = int_target_page
        save_local_config(lo_config)

        config = mw.addonManager.getConfig(__name__)
        if config["homescreen"] == True:
            write_config("homescreen_data", [])

        if mw.state == "deckBrowser":
            try:
                from ..lb_on_homescreen import refresh_home_board
                refresh_home_board()
            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e}")
    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

#MARK:max row
def on_select_max_row(key_index):
    try:
        key_index = int(key_index)

        from ..config_local import get_local_config, save_local_config
        lo_config = get_local_config()
        lo_config["max_users_v2"] = key_index
        save_local_config(lo_config)

        config = mw.addonManager.getConfig(__name__)
        if config["homescreen"] == True:
            write_config("homescreen_data", [])

        if mw.state == "deckBrowser":
            try:
                from ..lb_on_homescreen import refresh_home_board
                refresh_home_board()
            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e}")

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")


#MARK:home-del-cache
def delete_lo_conf_cache(*args, **kwargs):
    try:
        from ..config_local import get_local_config, save_local_config
        lo_config = get_local_config()
        lo_conf_keys = [
                        "home_selected_league",
                        "home_selected_country",
                        "manually_user_index"
                        ]

        is_changed = False
        for lo_conf_key in lo_conf_keys:
            if lo_config.get(lo_conf_key):
                lo_config[lo_conf_key] = None
                is_changed = True

        if is_changed:
            save_local_config(lo_config)
            config = mw.addonManager.getConfig(__name__)
            if config["homescreen"] == True:
                write_config("homescreen_data", [])

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")


def on_profile_did_open(*args, **kwargs):
    try:
        delete_lo_conf_cache()
        print(f"[{ADDON_NAME}] > delete_lo_conf_league")

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

# from aqt.main import MainWindowState
def on_state_did_change(new_state, old_state):
    try:
        if old_state == "deckBrowser" and new_state != "deckBrowser":
            delete_lo_conf_cache()
            print(f"[{ADDON_NAME}] > delete_lo_conf_league")

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")



#MARK:show home
def on_toggle_show_home(value):
    if value == "true":
        write_config("homescreen", True)
        tooltip("display the leaderboard on Anki home")
    elif value == "false":
        write_config("homescreen", False)
        tooltip("hide the leaderboard on Anki home :-/")
    else:
        print(f"[{ADDON_NAME}] Error-on_toggle_show_home: {value} ")



#MARK:autosync
def on_toggle_autosync(value):
    if value == "true":
        write_config("autosync", True)
        tooltip("after reviews are complete it will automatically sync")
    elif value == "false":
        write_config("autosync", False)
        tooltip("do nothing :-/")
    else:
        print(f"[{ADDON_NAME}] Error-on_toggle_autosync: {value} ")


#MARK:hide-buttons
def on_toggle_show_home_buttons(value):
    if value == "true":
        write_config("show_home_buttons", True)
        tooltip("Show the home buttons and ui")
    elif value == "false":
        write_config("show_home_buttons", False)
        tooltip("Hide the home buttons and ui")
    else:
        print(f"[{ADDON_NAME}] Error-on_toggle_show_home_buttons: {value} ")


#MARK:discord button
def on_toggle_discord_button(value):
    if value == "true":
        write_config("discord_button", True)
        tooltip("Show the discord buttons")
    elif value == "false":
        write_config("discord_button", False)
        tooltip("Hide the discord buttons")
    else:
        print(f"[{ADDON_NAME}] Error-discord buttons: {value} ")




#MARK:yesterday
def on_toggle_start_yesterday(value):
    if value == "true":
        write_config("start_yesterday", True)
        tooltip("calculate for yesterday and today")

    elif value == "false":
        write_config("start_yesterday", False)
        tooltip("calculate only for today")

    else:
        print(f"[{ADDON_NAME}] Error-on_toggle_start_yesterday: {value} ")

    config = mw.addonManager.getConfig(__name__)
    if config["homescreen"] == True:
        write_config("homescreen_data", [])






#MARK: hooks
def set_gui_hooks_leaderboard():
    try:
        gui_hooks.webview_did_receive_js_message.remove(on_webview_did_receive_js_message)
        gui_hooks.webview_did_receive_js_message.append(on_webview_did_receive_js_message)
        gui_hooks.state_did_change.append(on_state_did_change)
        gui_hooks.profile_did_open.append(on_profile_did_open)

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")