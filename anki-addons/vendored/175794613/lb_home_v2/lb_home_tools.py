# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import base64
from ..path_manager import ADDON_NAME

_icon_cache = {}

is_gamification_mode = True

def set_gamification_mode(is_true):
    global is_gamification_mode
    is_gamification_mode = is_true


#MARK:tool make icon
def make_icon_html(icon_path, size, no_width=None, only_data=False):
    try:
        global is_gamification_mode
        if not is_gamification_mode:
            return ""

        if icon_path in _icon_cache:
            b64_data = _icon_cache[icon_path]
        else:
            with open(icon_path, "rb") as img_file:
                b64_data = base64.b64encode(img_file.read()).decode("utf-8")

        if only_data:
            return f"data:image/png;base64,{b64_data}"

        if no_width:
            str_width = ""
        else:
            str_width = f'width="{size}"'

        icon_html = (f'<img src="data:image/png;base64,{b64_data}"'
                    f' {str_width} height="{size}" '
                    f'style="user-select:none; pointer-events:none;"'
                    f'>')
        return icon_html

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")
        return icon_path

#MARK:tool align mid
def add_align_middle(text):
    # 画像を囲む文字は囲まない
    return f'<span style="vertical-align: middle;">{text}</span>'



#MARK:multipleBox
def make_multiple_box(icon_html, display_text):
    str_streaks_html = (
                f'<div style="display:flex; align-items:center; width:100%;">'
                    f'<div style="display:block; flex-direction:column; align-items:center;">{icon_html}</div>'
                    f'<div style="display:block; margin:2px;text-align:center;">{display_text}</div>'
                    # f'<div style="display:flex; flex-direction:column; margin:2px;text-align:center;">{display_text}</div>'
                f'</div>'
            )
    return str_streaks_html


#MARK:font-size
# <span style="font-size:80%">

        # display_text = (f'{int(perday):,} /d'
        #                 f'<br>'
        #                 f'<span style="font-size:80%">'
        #                 f'({int(cards_31day):,} rev)'
        #                 f'</span>'
        #                 )

    # str_span_font_size = '<span style="font-size:80%">'
    # str_span_end = '</span>'



#MARK:checkbox

def make_checkbox_mini(
                        text,
                        element_id,
                        pycmd_key,
                        is_checked,
                        ):
    try:
        try:
            from aqt.theme import theme_manager
            nightmode = theme_manager.night_mode
        except:
            nightmode = False

        if nightmode:
            str_disabled_color = '#545454'
            str_enable_color = '#fcfcfc'
        else:
            str_disabled_color = '#afafaf'
            str_enable_color = '#020202'

        str_enable_text = f"[x] {text}"
        str_disable_text = f"[ ] {text}"

        if is_checked:
            data_checked = "true"
            str_now_color = str_enable_color
            str_now_text = str_enable_text
        else:
            data_checked = "false"
            str_now_color = str_disabled_color
            str_now_text = str_disable_text

        checkbox_html =  f"""\
    <span class="lb_box_text">
        <span id="{element_id}"
            style="cursor:pointer; font-size:12px; vertical-align: middle; color:{str_now_color};"
            data-checked="{data_checked}"
            onclick="
                var element = this;
                var isChecked = element.getAttribute('data-checked') === 'true';
                if (isChecked) {{
                    element.setAttribute('data-checked', 'false');
                    element.style.color = '{str_disabled_color}';
                    element.textContent = '{str_disable_text}';
                }} else {{
                    element.setAttribute('data-checked', 'true');
                    element.style.color = '{str_enable_color}';
                    element.textContent = '{str_enable_text}';
                }}
                var checkedValue = element.getAttribute('data-checked') === 'true';
                var checkedText = checkedValue ? 'true' : 'false';
                pycmd('{pycmd_key}:' + checkedText);
                "
            >
            {str_now_text}
        </span>
    </span>
    """
        return checkbox_html

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")



def make_checkbox_normal(
                        text,
                        element_id,
                        pycmd_key,
                        is_checked,
                    ):

    try:
        try:
            from aqt.theme import theme_manager
            nightmode = theme_manager.night_mode
        except:
            nightmode = False

        if nightmode:
            str_accent_color = "gray"
        else:
            str_accent_color = "white"

        if is_checked:
            checked = "checked"
        else:
            checked = ""

        checkbox_html = f"""\
    <span class="lb_box_text">
        <label style="cursor:pointer; display:inline-flex;">
            <input type="checkbox" id="{element_id}" {checked}
                onchange="pycmd('{pycmd_key}:' + (this.checked ? 'true' : 'false'))"
                style="vertical-align: vertical-align: middle; accent-color:{str_accent_color};">
            <span style="vertical-align: middle; font-size:13px;">
                {text}
            </span>
        </label>
    </span>
    """
        return checkbox_html

    except Exception as e:
        print(f"[{ADDON_NAME}] Error: {e}")
        return ""