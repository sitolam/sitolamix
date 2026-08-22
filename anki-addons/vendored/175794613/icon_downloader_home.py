# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import os
import time
import json
import base64
import requests

from aqt import mw, gui_hooks
from anki.utils import pointVersion
from aqt.operations import QueryOp
from aqt.qt import QTimer

from .api_constants import GET_ICON_IMAGE_TIMEOUT, GET_ICON_DICT_TIMEOUT
from .path_manager import ADDON_NAME
from .config_local import get_local_config, get_user_files_path
from .custom_shige.rate_limit_timer import rate_limit

ICONS_DOWNLOAD_INTERVAL = 100

BASE_ICONS_URL = "https://shigeyuki.pythonanywhere.com/static/user_icons/"

GET_DICT_REQUEST = "https://shigeyuki.pythonanywhere.com/shige_api/get_user_icons/"

ID_ICON_PLACEHOLDER = "shige-icon-placeholder"
STR_PLACEHOLDER = "placeholder"


def get_icon_cache_folder():
    addon_path = os.path.dirname(__file__)
    save_directory = os.path.join(addon_path, "user_files", "icon_cache")
    if not os.path.exists(save_directory):
        os.makedirs(save_directory)
    return save_directory


#MARK:IconDownloaderV2
class HomeIconDownloader:

    def __init__(self):

        self.list_need_dl_icon_pack = []
        self.stop_download_flag = False
        self.is_running = False

        self.save_directory = get_icon_cache_folder()

        self.list_need_dl_icons = []
        self.is_get_path_running = False

        self.user_icons_data = []
        self.saved_icons_data = []
        # self.start_get_user_icons_dict()


    #MARK:check dict
    def check_icon_dict_exists(self):
        if not self.user_icons_data:
            self.start_get_user_icons_dict()


    #MARK:DL-database
    def start_get_user_icons_dict(self, *args, **kwargs):
        if rate_limit.limit("start_get_user_icons_data", 60):
            return

        op = QueryOp(
            parent=mw,
            op=self.get_icons_dict_background,
            success=self.get_dict_success
        )

        if pointVersion() >= 231000:
            op.without_collection()

        try:
            op.failure(self.on_dict_dl_failure)
        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {e}")

        op.run_in_background()


    def on_dict_dl_failure(self, failure, *args, **kwargs):
        print(f"[{ADDON_NAME}] Error, icon dict dl:\n\n {failure}\n\n")


    #MARK:DL-bkground
    def get_icons_dict_background(self, col, *args, **kwargs):
        try:
            start_time = time.time()
            from .api_connect import  get_requests_session

            if get_local_config().get("debug_mode"):
                # ------ debug only ------------
                from requests import utils
                headers = utils.default_headers()
                headers['X-shige-debug-data'] = "debug_mode"
                response = get_requests_session().get(
                    GET_DICT_REQUEST,
                    timeout=GET_ICON_DICT_TIMEOUT,
                    headers=headers
                    )
                # ------------------------------

            else:
                response = get_requests_session().get(
                    GET_DICT_REQUEST,
                    timeout=GET_ICON_DICT_TIMEOUT
                )

            end_time = time.time()
            elapsed_time = end_time - start_time

            if hasattr(response, "status_code") and response.status_code == 200:
                self.user_icons_data = response.json()
                try:
                    self.save_json_to_file(self.user_icons_data)
                    print(f"Icon-Dict-DL: {elapsed_time:.4f} sec, size: {len(response.content)/1024/1024:.2f} MB")
                except Exception as e:
                    print(f"[{ADDON_NAME}] Error: {e}")

                # --------debug only -------------
                try:
                    if get_local_config().get("debug_mode"):
                        debug_data_json = response.headers.get('X-shige-debug-data')
                        if debug_data_json:
                            debug_data = json.loads(debug_data_json)
                            for line in debug_data:
                                print(f"[{ADDON_NAME}] {line}")
                except Exception as e:
                    print(f"[{ADDON_NAME}] Error: {e}")
                # --------debug only -------------

                return "Success"

            else:
                self.saved_icons_data = self.load_json_from_file()
                print(f"[{ADDON_NAME}] Icons: use local cache")

                return response.text

        except requests.exceptions.Timeout:
            return "timeout error"
        except requests.exceptions.ConnectionError:
            return "ConnectionError"
        except requests.exceptions.HTTPError as e:
            return f"HTTPError: {e}"
        except requests.exceptions.RequestException as e:
            return f"RequestException: {e}"
        except Exception as e:
            return f"Exception: {e}"



    def get_dict_success(self, result):
        if result == "Success":
            self.setup_del_unused_icons()

        else:
            print(f"[{ADDON_NAME}] Error: {result}")

    #MARK:save & load
    def save_json_to_file(self, data):
        try:
            save_path = os.path.join(get_user_files_path(), "icon_dict_cache.json")
            json_str = json.dumps(data, ensure_ascii=False)
            encoded = base64.b64encode(json_str.encode("utf-8")).decode("utf-8")
            with open(save_path, "w", encoding="utf-8") as f:
                f.write(encoded)
            return True

        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {e}")
            return False

    def load_json_from_file(self):
        try:
            load_path = os.path.join(get_user_files_path(), "icon_dict_cache.json")
            if not os.path.exists(load_path):
                return []
            with open(load_path, "r", encoding="utf-8") as f:
                encoded = f.read()
                json_str = base64.b64decode(encoded.encode("utf-8")).decode("utf-8")
                return json.loads(json_str)
        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {e}")
            return []



    # ---------------------------------------

    #MARK:delUnused
    def setup_del_unused_icons(self, *args, **kwargs):
        self.list_unused_icons_need_delete = []

        # 削除しないｱｲｺﾝ
        files_to_keep = []
        for user_icon_data in self.user_icons_data:
            file_name = user_icon_data[1] + '.bin'
            files_to_keep.append(file_name)
        self.keep_files = files_to_keep

        if os.path.exists(self.save_directory):
            for filename in os.listdir(self.save_directory):
                file_path = os.path.join(self.save_directory, filename)

                # 拡張子が.binでありuser_icons_dataに含まれていないもののみ削除
                if (os.path.isfile(file_path)
                    and file_path.endswith('.bin')
                    and filename not in self.keep_files):

                    if 'user_files' not in file_path:
                        continue

                    self.list_unused_icons_need_delete.append(file_path)

        self.need_del_next_unused_icon()


    def need_del_next_unused_icon(self):
        if self.stop_download_flag:
            return

        if not self.list_unused_icons_need_delete:
            return

        icon_file_path = self.list_unused_icons_need_delete.pop(0)
        op = QueryOp(
            parent=mw,
            op=lambda col: self.on_delete_icon(icon_file_path),
            success=lambda result: QTimer.singleShot(500, self.need_del_next_unused_icon)
        )

        if pointVersion() >= 231000:
            op.without_collection()

        try:
            op.failure(self.on_failure_del_icon)
        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {e}")

        op.run_in_background()

    def on_delete_icon(self, unused_icon_path):
        try:
            os.remove(unused_icon_path)
        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {unused_icon_path}, {e}")


    def on_failure_del_icon(self, failure, *args, **kwargs):
        print(f"[{ADDON_NAME}] Error, del_icon:\n\n {failure}\n\n")

    # ---------------------------------------




    #📍use from other .py file
    #MARK:get_by_username
    def get_by_username(self, username, size):

        local_image_path, user_file_name, image_url = self.get_icon_path(username)

        if os.path.exists(local_image_path):
            # 画像があればｱｲｺﾝとﾂｰﾙﾁｯﾌﾟを作る
            local_image_path, image_data = self.on_convert_icon(local_image_path)
            if image_data:
                #MARK:HTML-tooltip
                # new_text = f'<img src="{local_image_path}" width="{size}" height="{size}"><br>'
                new_text = f'<img src="{local_image_path}" width="{size}" height="{size}" >'

                path_exists = True
                return path_exists, image_data, new_text # GUI
            else:
                #fileが壊れている?
                image_data = None
                new_text = None
                path_exists = False
                return path_exists, image_data, new_text

        else:
            image_data = None
            new_text = None
            path_exists = False

            if user_file_name != "":
                # PATHはあるが画像がない -> ﾀﾞｳﾝﾛｰﾄﾞをﾘｸｴｽﾄ
                item_pack = (username, size)
                item_main = (local_image_path, image_url, user_file_name, item_pack)

                if item_main not in self.list_need_dl_icon_pack:
                    self.list_need_dl_icon_pack.append(item_main)

                placeholder_text = (
                                    f'<span '
                                        f'class="{ID_ICON_PLACEHOLDER}" '
                                        f'data-userid="{user_file_name}">'
                                    f'</span>')
                new_text = placeholder_text
                path_exists = STR_PLACEHOLDER

            return path_exists, image_data, new_text


    #MARK:get_icon_path
    def get_icon_path(self, username):
        # BackGround
        if not os.path.exists(self.save_directory):
            os.makedirs(self.save_directory)

        local_image_path = ""
        user_file_name = ""
        image_url =  ""

        user_icons_data = self.user_icons_data

        if not self.user_icons_data and self.saved_icons_data:
            user_icons_data = self.saved_icons_data

        for item in user_icons_data:
            if username == item[0]:
                user_file_name = item[1]
                image_url = f"{BASE_ICONS_URL}{user_file_name}.png"
                local_image_path = os.path.join(self.save_directory, f"{item[1]}.bin")
                break

        return local_image_path, user_file_name, image_url


    #MARK:deobfuscate
    # ﾛｰｶﾙのﾊﾞｲﾅﾘｱｲｺﾝをQIconとHTMLﾀｸﾞ用に変換
    def on_convert_icon(self, local_image_path):
        # BackGround
        try:
            with open(local_image_path, "rb") as obfuscated_file:
                obfuscated_data = obfuscated_file.read()
                image_data = base64.b64decode(obfuscated_data)

            image_base64 = base64.b64encode(image_data).decode('utf-8')
            html_image_tag = f'data:image/png;base64,{image_base64}'

            return html_image_tag, image_data

        except FileNotFoundError:
            return '', None


    #MARK:startDLv2
    def on_icon_download_v2(self, col, *args, **kwargs):
        # background threads

        try:
            if not self.list_need_dl_icon_pack:
                return

            from .api_connect import get_requests_session

            item = self.list_need_dl_icon_pack.pop(0)

            local_image_path, image_url, user_file_name, item_pack = item
            user_name, image_size = item_pack

            # DL
            str_requests_error = ""
            try:
                start_time = time.time()
                response = get_requests_session().get(
                                image_url,
                                timeout=GET_ICON_IMAGE_TIMEOUT
                                )
                end_time = time.time()
                elapsed_time = end_time - start_time
                print(f"[Icon-DL] {elapsed_time:.4f} sec")

            except requests.exceptions.Timeout:
                str_requests_error = "Timeout"
            except requests.exceptions.ConnectionError:
                str_requests_error = "ConnectionError"
            except requests.exceptions.HTTPError as e:
                str_requests_error = "HTTPError"
            except requests.exceptions.RequestException as e:
                str_requests_error = "RequestException"
            if str_requests_error:
                return str_requests_error


            if hasattr(response, "status_code") and response.status_code == 200:
                image_data = response.content
                obfuscated_data = base64.b64encode(image_data)

                with open(local_image_path, 'wb') as file:
                    file.write(obfuscated_data)

                if os.path.exists(local_image_path):
                    # 画像があればｱｲｺﾝとﾂｰﾙﾁｯﾌﾟを作る
                    image_source, image_data = self.on_convert_icon(local_image_path)

                    if image_data:
                        # new_icon_img = f'<img src="{local_image_path}" width="{size}" height="{size}" >'
                        result = [user_file_name, image_source, image_size]
                        return result

                else:
                    print(f"[{ADDON_NAME}] Error, icon not found: {local_image_path}")

            else:
                print(f"[{ADDON_NAME}] Error-response: {response} ")

            return None


        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {e}")

            return None


    def on_success_v2(self, result):

        try:
            if isinstance(result, list) and len(result) == 3:
                user_file_name, image_source, image_size = result
                self.on_replace_placeholder(user_file_name, image_source, image_size)
            else:
                print(f"[{ADDON_NAME}] Error-on_success_v2: {result}")

            if self.list_need_dl_icon_pack:
                QTimer.singleShot(
                    ICONS_DOWNLOAD_INTERVAL,
                    self.start_download_v2)
            else:
                self.is_running = False

        except Exception as e:
            print(f"[{ADDON_NAME}] Error {e} ")


    #MARK:START DL
    def request_dl_v2(self):
        if self.is_running:
            # dl already progress
            return

        if not mw.state == "deckBrowser":
            self.is_running = False
            return

        if self.list_need_dl_icon_pack:
            self.is_running = True
            self.start_download_v2()


    #MARK:dl-loop
    def start_download_v2(self):

        try:
            if self.stop_download_flag:
                self.is_running = False
                return

            if not mw.state == "deckBrowser":
                self.is_running = False
                return

            op = QueryOp(
                parent=mw,
                op=self.on_icon_download_v2,
                success=self.on_success_v2
            )

            if pointVersion() >= 231000:
                op.without_collection()

            try:
                op.failure(self.on_icon_dl_failure)
            except Exception as e:
                print(f"[{ADDON_NAME}] Error: {e}")

            op.run_in_background()

        except Exception as e:
            print(f"[{ADDON_NAME}] Error: {e} ")


    def on_icon_dl_failure(self, failure, *args, **kwargs):
        # print(f"[{ADDON_NAME}] Error, icon dl:\n\n {failure}\n\n")
        self.on_success_v2(failure)


    #MARK:placeholder
    def on_replace_placeholder(self,
                                user_file_name,
                                image_source,
                                image_size
                                ):

        if not mw.state == "deckBrowser":
            self.is_running = False
            return

        from .lb_on_homescreen import SHIGE_LB_CONTAINER

        js_code = f"""
        (function() {{
            var container = document.getElementById('{SHIGE_LB_CONTAINER}');
            if (container && container.shadowRoot) {{
                var shadowRoot = container.shadowRoot;
                var placeholder = shadowRoot.querySelector(
                    '.{ID_ICON_PLACEHOLDER}[data-userid="{user_file_name}"]'
                );
                if (placeholder) {{
                    var imageElement = document.createElement('img');
                    imageElement.src = '{image_source}';
                    imageElement.width = {image_size};
                    imageElement.height = {image_size};
                    placeholder.parentNode.replaceChild(imageElement, placeholder);
                }}
            }}
        }})();
        """
        mw.deckBrowser.web.eval(js_code)



#MARK:downloader
home_icon_downloader = None
try:
    home_icon_downloader = HomeIconDownloader()
except Exception as e:
    print(f"[{ADDON_NAME}] Error: {e}")



#MARK:del cache hoook
def on_state_did_change(new_state, old_state, *args, **kwargs):
    try:
        if not new_state == "deckBrowser" and home_icon_downloader:
            home_icon_downloader.stop_download_flag = True
            home_icon_downloader.list_need_dl_icon_pack = []
            return

    except Exception as e:
        print(f"[{ADDON_NAME}] Error {e}")


gui_hooks.state_did_change.append(on_state_did_change)
