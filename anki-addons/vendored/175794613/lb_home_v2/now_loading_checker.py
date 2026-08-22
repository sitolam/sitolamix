# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import time

from aqt import mw, gui_hooks

try:
    from PyQt6.QtCore import QTimer
except:
    from aqt.qt import QTimer

from ..path_manager import ADDON_NAME
from ..custom_shige.path_manager import NOW_LOADING_GIF, NOW_LOADING_GIF_DARK
from ..lb_home_v2.lb_home_tools import make_icon_html, add_align_middle


# deckBrowserで1秒ごとにﾛｰﾄﾞ中かﾁｪｯｸ
# web.evalでｱｲｺﾝを追加&削除


ID_SHIGE_SYNC_LOADING_ICON = "shige_sync_loading_icon"
ID_SHIGE_LB_NOW_LOADING_TEXT = "shige_lb_now_loading_text"

#MARK:load cheker
def loading_checker():
    try:
        from .. import check_now_loading_bg
        from ..lb_on_homescreen import check_is_now_loading
        if check_now_loading_bg() or check_is_now_loading():
            return True
        else:
            return False
    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")


now_loading_timer = None


def start_loading_checker(new_state, old_state, *args, **kwargs):

    try:
        if not new_state == "deckBrowser":
            return

        global now_loading_timer
        if now_loading_timer is None:
            now_loading_timer = QTimer()
            now_loading_timer.setInterval(1000)
            now_loading_timer.timeout.connect(check_loading_status)
            now_loading_timer.start()

    except Exception as e:
        print(f"[{ADDON_NAME}] Error {e}")

def set_sync_check_timer_hook():
    gui_hooks.state_did_change.append(start_loading_checker)


#📍user from other .py file
def start_loading_timer(*args, **kwargs):
    try:
        # add_loading_icon()
        return

    except Exception as e:
        print(f"[{ADDON_NAME}] Error] {e}")



def stop_loading_timer():
    try:
        global now_loading_timer
        if now_loading_timer is not None:
            now_loading_timer.stop()
            now_loading_timer = None

    except Exception as e:
        print(f"[{ADDON_NAME}] Error {e}")



def check_loading_status():
    try:
        if not mw:
            return

        if not mw.state == "deckBrowser":
            stop_loading_timer()
            return

        if not loading_checker():
            hide_now_loading()
            # stop_loading_timer()
        else:
            add_loading_icon()

    except Exception as e:
        print(f"[{ADDON_NAME}] Error {e} ")
        try:
            stop_loading_timer()
        except Exception as e:
            print(f"[{ADDON_NAME}] Error {e}")


def hide_now_loading():
    try:
        if not mw.state == "deckBrowser":
            return

        from ..lb_on_homescreen import SHIGE_LB_CONTAINER

        js_script = f"""
            (function() {{

                // shadow
                var container = document.getElementById('{SHIGE_LB_CONTAINER}');
                if (container && container.shadowRoot) {{
                    var shadow = container.shadowRoot;
                    var loadingTextsShadow = shadow.querySelectorAll('#{ID_SHIGE_SYNC_LOADING_ICON}');
                    loadingTextsShadow.forEach(function(loadingText) {{
                        if (loadingText) {{
                            loadingText.innerHTML = '';
                        }}
                    }});
                }}

                // normal
                if (container) {{
                    var loadingTextsOuter = container.querySelectorAll('#{ID_SHIGE_LB_NOW_LOADING_TEXT}');
                    loadingTextsOuter.forEach(function(loadingText) {{
                        if (loadingText) {{
                            loadingText.innerHTML = '';
                        }}
                    }});
                }}
            }})();
        """
        mw.deckBrowser.web.eval(js_script)

    except Exception as e:
        print(f"[{ADDON_NAME}] Error {e}")
        try:
            stop_loading_timer()
        except Exception as e:
            print(f"[{ADDON_NAME}] Error {e}")


#MARK:load icon
def make_loading_icon():
    try:
        from aqt.theme import theme_manager
        nightmode = theme_manager.night_mode
    except:
        nightmode = False

    if nightmode:
        icon_path = NOW_LOADING_GIF_DARK
    else:
        icon_path = NOW_LOADING_GIF

    loading_icon_html = make_icon_html(icon_path, 20)

    return loading_icon_html


#MARK:add loading icon
def add_loading_icon():
    if not mw.state == "deckBrowser":
        return

    loading_icon = make_loading_icon()
    loading_icon = add_align_middle(loading_icon)

    loading_icon_html = f'<span id="{ID_SHIGE_LB_NOW_LOADING_TEXT}">{loading_icon}</span>'
    loading_icon_html_with_text = (
                    f'<span id="{ID_SHIGE_LB_NOW_LOADING_TEXT}">'
                    f': Now Loading...'
                    f'{loading_icon}'
                    f'</span>'
                    )

    from ..lb_on_homescreen import SHIGE_LB_CONTAINER
    js_script = f"""
(function() {{

    // shadow
    var container = document.getElementById('{SHIGE_LB_CONTAINER}');
    if (container && container.shadowRoot) {{
        var shadow = container.shadowRoot;
        var loadingIcon = shadow.getElementById('{ID_SHIGE_SYNC_LOADING_ICON}');
        if (loadingIcon) {{
            if (loadingIcon && loadingIcon.innerHTML.trim() === '') {{
                loadingIcon.innerHTML = `{loading_icon_html}`;
            }}
        }}
    }}

    // nomal
    var loadingTextElem = container && container.querySelector('#{ID_SHIGE_LB_NOW_LOADING_TEXT}');
    if (loadingTextElem && loadingTextElem.innerHTML.trim() === '') {{
        loadingTextElem.innerHTML = `{loading_icon_html_with_text}`;
    }}
}})();
"""

    mw.deckBrowser.web.eval(js_script)



#MARK:last sync

_last_sync_time = ""
def save_last_sync_time():
    global _last_sync_time
    _last_sync_time = time.time()
    return

def get_last_sync_time_info():
    try:
        global _last_sync_time
        if not _last_sync_time:
            return ""

        str_last_sync_time_info = ""

        elapsed = time.time() - _last_sync_time

        if elapsed < 60:
            str_last_sync_time_info = (
                                        f'<span style="color: #93c5fd;">'
                                        f'Last-sync: '
                                        f'{int(elapsed)}'
                                        f' sec ago'
                                        f'</span>'
                                        )
        elif elapsed < 3600:
            str_last_sync_time_info = f"Last-sync: {int(elapsed // 60)} mins ago"
        else:
            str_last_sync_time_info = f"Last-sync: {int(elapsed // 3600)} hours ago"

        return str_last_sync_time_info

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e} ")
        return ""


def show_last_sync_tooltip():
    try:
        from ..lb_on_homescreen import SHIGE_LB_CONTAINER
        sync_text = get_last_sync_time_info()
        js_script = f"""
        (function() {{
            var container = document.getElementById('{SHIGE_LB_CONTAINER}');
            if (container && container.shadowRoot) {{
                var shadow = container.shadowRoot;
                var syncIcon = shadow.getElementById('{ID_SHIGE_SYNC_LOADING_ICON}');
                if (syncIcon) {{
                    syncIcon.title = "{sync_text}";
                }}
            }}
        }})();
        """
        mw.deckBrowser.web.eval(js_script)

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")


def on_sync_info_tooltip(action):
    try:
        from ..lb_on_homescreen import SHIGE_LB_CONTAINER
        tooltip_span_id = "shige_sync_tooltip"
        sync_info_text = get_last_sync_time_info()

        if action == "show":
            js_script = f"""
            (function() {{
                var mainContainer = document.getElementById('{SHIGE_LB_CONTAINER}');
                if (mainContainer === null) {{
                    return;
                }}
                if (mainContainer.shadowRoot === null) {{
                    return;
                }}
                var shadowRoot = mainContainer.shadowRoot;
                var tooltipSpan = shadowRoot.getElementById('{tooltip_span_id}');
                if (tooltipSpan === null) {{
                    return;
                }}
                tooltipSpan.style.display = 'block';
                tooltipSpan.innerHTML = '{sync_info_text}';
            }})();"""

        elif action == "hide":
            js_script = f"""
            (function() {{
                var mainContainer = document.getElementById('{SHIGE_LB_CONTAINER}');
                if (mainContainer === null) {{
                    return;
                }}
                if (mainContainer.shadowRoot === null) {{
                    return;
                }}
                var shadowRoot = mainContainer.shadowRoot;
                var tooltipSpan = shadowRoot.getElementById('{tooltip_span_id}');
                if (tooltipSpan !== null) {{
                    tooltipSpan.style.display = 'none';
                }}
            }})();"""

        else:
            return

        mw.deckBrowser.web.eval(js_script)

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")

def sync_info_tooltip_style(str_text_color, str_background_color):
    sync_tooltip_css = f"""
<style>
.shige_sync_tooltip {{
    position: absolute;
    left: -40px;
    top: -40px;
    background: {str_background_color};
    color: {str_text_color};
    padding: 4px 8px;
    border-radius: 4px;
    z-index: 100;
    display: none;
    pointer-events: none;
    white-space: nowrap;
}}
</style>"""

    return sync_tooltip_css