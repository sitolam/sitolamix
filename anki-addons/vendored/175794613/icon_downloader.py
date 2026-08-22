# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>

import base64
import json
import os
import requests
import time

from aqt.operations import QueryOp
from anki.utils import pointVersion
from aqt import mw, QIcon, QPixmap, QTimer, QTableWidget

from .api_constants import GET_ICON_IMAGE_TIMEOUT, GET_ICON_DICT_TIMEOUT
from .path_manager import ADDON_NAME
from .config_local import get_local_config, get_user_files_path


from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .Leaderboard import start_main

ICONS_DOWNLOAD_INTERVAL = 100
TOOLTIP_AND_ICON_INTERVAL = 10

MAX_EXECUTIONS = 99999

# DEFAULT_ICON_PATH = "https://shigeyuki.pythonanywhere.com/static/user_icons/tmpwxfki_ko.png"
BASE_ICONS_URL = "https://shigeyuki.pythonanywhere.com/static/user_icons/"
DEFAULT_ICON_PATH = None


GET_DICT_REQUEST = "https://shigeyuki.pythonanywhere.com/shige_api/get_user_icons/"

NOT_USE_LIST = True

class IconDownloader:
    def __init__(self, parent:"start_main"):
        self.parent = parent

        ### download from server ###
        self.icons_dl_list = []
        self.stop_download_flag = False
        self.is_running = False

        ### make icon and tooltip ###
        self.addon_path = os.path.dirname(__file__)
        self.save_directory = os.path.join(self.addon_path, "user_files", "icon_cache")
        if not os.path.exists(self.save_directory):
            os.makedirs(self.save_directory)

        self.get_path_icons_list = []
        self.is_get_path_running = False

        ### ｻｰﾊﾞｰからｱｲｺﾝ名のﾃﾞｰﾀを取得 ###
        # TODO: ﾛｰｶﾙに保存してﾃﾞｰﾀを取得
        self.user_icons_data = []
        self.start_get_user_icons_data()
        # gui_hooks.main_window_did_init.append(self.start_get_user_icons_dict)

        ### test ###
        self.execution_count = 0
        self.max_executions = MAX_EXECUTIONS

        # TODO: ﾘｰﾀﾞｰﾎﾞｰﾄﾞごとにｱｲｺﾝのDLをｵﾝｵﾌする関数
        #        -> ﾕｰｻﾞｰが増えるとｷｬｯｼｭが重くなる
        #           10-100kb/1user, 10,000user->100MB, 100,000user->1GB
        # self.parent.dialog.League
        # self.parent.dialog.Friends_Leaderboard
        # self.parent.dialog.Custom_Leaderboard
        # self.parent.dialog.Country_Leaderboard
        # self.parent.dialog.Global_Leaderboard

        # TODO: 使ってないｱｲｺﾝ(7day-1month)を自動削除する関数

        # TODO: ｷｬｯｼｭをｸﾘｱする機能
        # TODO: 現在のﾌｧｲﾙｻｲｽﾞを表示する機能


    # ｻｰﾊﾞｰからﾃﾞｰﾀを取得 ---------------------
    def start_get_user_icons_data(self, *args, **kwargs):
        op = QueryOp(
            parent=self.parent,
            op=lambda col: self.get_user_icons_name_data_in_background(),
            success=lambda result: self.get_data_success(result)
        )
        if pointVersion() >= 231000:
            op.without_collection()
        op.run_in_background()

    def get_user_icons_name_data_in_background(self):
        try:
            start_time = time.time()
            from .api_connect import  get_requests_session

            if get_local_config().get("debug_mode"):
                from requests import utils
                headers = utils.default_headers()
                headers['X-shige-debug-data'] = "debug_mode"
                response = get_requests_session().get(GET_DICT_REQUEST, timeout=GET_ICON_DICT_TIMEOUT, headers=headers)

            else:
                response = get_requests_session().get(GET_DICT_REQUEST, timeout=GET_ICON_DICT_TIMEOUT)

            end_time = time.time()
            elapsed_time = end_time - start_time

            if response.status_code == 200:
                self.user_icons_data = response.json()
                try:
                    print(f"Icon-Dict-DL: {elapsed_time:.4f} sec, size: {len(response.content)/1024/1024:.2f} MB")

                    if get_local_config().get("debug_mode"):
                        save_path = os.path.join(get_user_files_path(), "icon_dict_dl.json")
                        with open(save_path, "w", encoding="utf-8") as f:
                            json.dump(self.user_icons_data, f, ensure_ascii=False, indent=2)
                            print(f"[{ADDON_NAME}] debug: save Icon-Dict json")

                        debug_data_json = response.headers.get('X-shige-debug-data')
                        if debug_data_json:
                            debug_data = json.loads(debug_data_json)
                            for line in debug_data:
                                print(f"[{ADDON_NAME}] {line}")

                except Exception as e:
                    print(f"[{ADDON_NAME}] Error: {e}")

                return "Success"
            else:
                return response.text
        except requests.exceptions.Timeout:
            print(f"Icon-Dict-DL: timeout error")
            return "timeout error"
        except requests.exceptions.RequestException as e:
            print(f"Icon-Dict-DL: request error")
            return "request error"

    def get_data_success(self, result):
        if result == "Success":
            self.start_remove_unused_icons()


    ### 使ってないｱｲｺﾝを削除 ---------------------
    def start_remove_unused_icons(self, *args, **kwargs):
        self.files_to_remove = []

        # 削除しないﾌｧｲﾙ名のﾘｽﾄを作成
        self.keep_files = [item[1] + '.bin' for item in self.user_icons_data]

        if os.path.exists(self.save_directory):
            for filename in os.listdir(self.save_directory):
                file_path = os.path.join(self.save_directory, filename)
                # 拡張子が.binのﾌｧｲﾙであり､user_icons_dataに含まれていないもののみを削除
                if os.path.isfile(file_path) and file_path.endswith('.bin') and filename not in self.keep_files:
                    if 'user_files' not in file_path:
                        continue
                    self.files_to_remove.append(file_path)
        self.remove_next_file()


    def remove_next_file(self):
        if self.stop_download_flag:
            return
        if not self.files_to_remove:
            return

        file_path = self.files_to_remove.pop(0)
        op = QueryOp(
            parent=self.parent,
            op=lambda col: self.remove_file(file_path),
            success=lambda result: QTimer.singleShot(1000, self.remove_next_file)
        )
        op.run_in_background()

    def remove_file(self, file_path):
        try:
            os.remove(file_path)
        except Exception as e:
            print(f'Failed to delete {file_path}. Reason: {e}')

    # -----------------------------------


    ### make icon and tooltip ###

    def get_local_image_path(self, user_name):
        # BackGround
        if not os.path.exists(self.save_directory):
            os.makedirs(self.save_directory)

        # # ﾌｧｲﾙ名に使えない文字列を除外(重複するかも?)
        # replace_text = r'[<>:"/\\|?*,.\U0001F600-\U0001F64F\n]'
        # user_file_name = re.sub(replace_text, '_', user_name)

        local_image_path = ""
        user_file_name = ""
        image_url =  ""

        for item in self.user_icons_data:
            if user_name == item[0]:
                user_file_name = item[1]
                image_url = f"{BASE_ICONS_URL}{user_file_name}.png"
                local_image_path = os.path.join(self.save_directory, f"{item[1]}.bin")

        return local_image_path, user_file_name, image_url


    def get_icon_path_from_username(self, tab_widget:QTableWidget, raw_number, user_name, size):

        local_image_path, user_file_name, image_url = self.get_local_image_path(user_name)

        if os.path.exists(local_image_path):
            # 画像があればｱｲｺﾝとﾂｰﾙﾁｯﾌﾟを作る
            local_image_path, image_data = self.deobfuscate_image(local_image_path)
            new_text = f'<img src="{local_image_path}" width="{size}" height="{size}"><br>'
            path_exists = True
            return path_exists, tab_widget, raw_number, image_data, new_text # GUI
        else:
            # if not user_file_name is "":
            if user_file_name != "":
                # PATHはあるが画像がないのでﾀﾞｳﾝﾛｰﾄﾞをﾘｸｴｽﾄ
                item_pack = (tab_widget, raw_number, user_name, size)
                self.add_user_icon_to_list(local_image_path, image_url, user_file_name, item_pack)
            image_data = None
            new_text = None
            path_exists = False
            return path_exists, tab_widget, raw_number, image_data, new_text


    # ﾘｽﾄに入れて順番に処理する ------------

    def add_make_path_and_icons_list(self, tab_widget, row_number, user_name, size):
        if NOT_USE_LIST:
            self.get_icon_path_in_front_and_direct(tab_widget, row_number, user_name, size)
        else:
            if (( tab_widget, row_number, user_name, size)
                    not in self.get_path_icons_list):
                self.get_path_icons_list.append(
                    ( tab_widget, row_number, user_name, size))

    # def add_make_path_and_icons_list(self, tab_widget, raw_number, image_data, new_text):
    #     if ((tab_widget, raw_number, image_data, new_text)
    #             not in self.get_path_icons_list):
    #         self.get_path_icons_list.append(
    #             (tab_widget, raw_number, image_data, new_text))

    # ﾛｰｶﾙのﾊﾞｲﾅﾘｱｲｺﾝをQIconとHTMLﾀｸﾞ用に変換
    def deobfuscate_image(self, obfuscated_path):
        # BackGround
        try:
            with open(obfuscated_path, "rb") as obfuscated_file:
                obfuscated_data = obfuscated_file.read()
                image_data = base64.b64decode(obfuscated_data)

            image_base64 = base64.b64encode(image_data).decode('utf-8')
            html_image_tag = f'data:image/png;base64,{image_base64}'

            return html_image_tag, image_data

        except FileNotFoundError:
            # print(f"File not found: {obfuscated_path}")
            return '', None

    # 保存しておいたﾘｽﾄを実行してDLする -------------
    def start_get_icon_path_in_background(self):
        # test 使ってない
        if self.is_get_path_running:
            # print("Download already in progress.")
            return
        if self.get_path_icons_list:
            self.is_get_path_running = True
            self.get_icon_path_in_background(0, self.get_path_icons_list)

    def get_icon_path_in_background(self, index, get_path_icons_list):
        # BackGround
        if self.stop_download_flag:
            self.is_get_path_running = False
            return

        tab_widget, raw_number, user_name, size  = get_path_icons_list[index]
        # op = QueryOp(
        #     parent=mw,
        #     op=lambda col,
        #     tab_widget=tab_widget,
        #     raw_number=raw_number,
        #     user_name=user_name,
        #     size=size: self.get_icon_path_from_username(tab_widget, raw_number, user_name, size),
        #     success=lambda result, index=index: self.get_icon_path_success(index, get_path_icons_list, result)
        # )
        # op.run_in_background()
        
        result = self.get_icon_path_from_username(tab_widget, raw_number, user_name, size)
        self.get_icon_path_success(index, get_path_icons_list, result)


    def get_icon_path_in_front_and_direct(self, tab_widget, raw_number, user_name, size):

        result = self.get_icon_path_from_username(tab_widget, raw_number, user_name, size)
        path_exists, tab_widget, raw_number, image_data, new_text = result

        if path_exists:
            # UI routines
            try:
                # self.make_user_icon_and_html(tab_widget, raw_number, image_data, new_text)
                self.make_user_icon_and_html(tab_widget, raw_number, image_data, new_text)
                # QTimer.singleShot(
                # TOOLTIP_AND_ICON_INTERVAL,
                # lambda: self.make_user_icon_and_html(tab_widget, raw_number, image_data, new_text))
            except RuntimeError:
                self.stop_download_flag = True
                pass
        else:
            pass


    # def get_icon_path_success(self, index, get_path_icons_list, path_exists, tab_widget, raw_number, image_data, new_text):
    def get_icon_path_success(self, index, get_path_icons_list, result):
        if self.stop_download_flag:
            self.is_get_path_running = False
            return
        path_exists, tab_widget, raw_number, image_data, new_text = result

        if path_exists:
            # UI routines
            try:
                self.make_user_icon_and_html(tab_widget, raw_number, image_data, new_text)
            except RuntimeError:
                self.stop_download_flag = True
                # print("RuntimeError: get_icon_path_success")
                pass
            # print(f"Succces: index: {index}: raw : {raw_number}")
        # else:
        #     print(f"file not found: index: {index}: raw : {raw_number}")

        next_index = index + 1

        while next_index < len(get_path_icons_list):
            tab_widget, raw_number, user_name, size = get_path_icons_list[next_index]
            tab_widget : "QTableWidget"

            try:
                item = tab_widget.item(raw_number, 0)
                if item is not None:
                    current_tooltip = item.toolTip()
                    if (current_tooltip is not None
                        and "data:image/png;base64," in current_tooltip
                        and not "<!--PLACEHOLDER-->" in current_tooltip ):
                        # print(f"tooltip already exists, skipping.")
                        next_index += 1
                    else:
                        # print(f"Processing.")
                        break
            except RuntimeError:
                self.stop_download_flag = True
                # print(f"RuntimeError, Processing.")
                break

        if next_index < len(get_path_icons_list):
            QTimer.singleShot(
                TOOLTIP_AND_ICON_INTERVAL,
                lambda: self.get_icon_path_in_background(next_index, get_path_icons_list))
        else:
            self.is_get_path_running = False
            # ﾂｰﾙﾁｯﾌﾟの処理がすべて終わったらｱｲｺﾝをﾀﾞｳﾝﾛｰﾄﾞ
            self.dl_icons_in_background()

    # ｱｲｺﾝとﾂｰﾙﾁｯﾌﾟを作る----------------
    def make_user_icon_and_html(self, tab_widget:"QTableWidget", raw_number, image_data, new_text):
        # UI routines
        user_icon = None
        if image_data:
            pixmap = QPixmap()
            pixmap.loadFromData(image_data)
            user_icon = QIcon(pixmap)
        if not user_icon is None:
            user_name_item = tab_widget.item(raw_number, 1)
            if user_name_item is not None:
                user_name_item.setIcon(user_icon)
                self.replace_text_in_tooltip(tab_widget, raw_number, new_text)

    def replace_text_in_tooltip(self, tab_widget:"QTableWidget", raw_number, new_text):
        # UI routines
        column_count = tab_widget.columnCount()

        config = mw.addonManager.getConfig(__name__)
        hide_all_users_name = config.get("hide_all_users_name", False)

        for column in range(column_count):
            item = tab_widget.item(raw_number, column)
            if item is not None:
                current_tooltip = item.toolTip()
                if current_tooltip and not hide_all_users_name:
                # if current_tooltip:
                    updated_tooltip = current_tooltip.replace("<!--PLACEHOLDER-->", new_text)
                    item.setToolTip(updated_tooltip)
    # --------------------------------------



    ### download from server ### これを使う

    def add_user_icon_to_list(self, local_image_path, image_url, user_file_name, item_pack):
        # self.icons_dl_listに保存
        if ((local_image_path, image_url, user_file_name, item_pack)
            not in self.icons_dl_list):
            self.icons_dl_list.append((local_image_path, image_url, user_file_name, item_pack))

    def get_icon_image(self, local_image_path, image_url):
        # print(local_image_path)
        # print(image_url)

        start_time = time.time()
        from .api_connect import get_requests_session
        response = get_requests_session().get(image_url, timeout=GET_ICON_IMAGE_TIMEOUT)
        end_time = time.time()

        if response.status_code == 200:
            image_data = response.content
            obfuscated_data = base64.b64encode(image_data)
            try:
                with open(local_image_path, 'wb') as file:
                    file.write(obfuscated_data)

                elapsed_time = end_time - start_time
                print(f"Icon-DL: {elapsed_time:.4f} sec")

            except FileNotFoundError:
                print(f"Icon-DL: Error File not found {local_image_path}")

        else:
            print(f"Icon-DL: Error response {image_url}")


    def start_download(self, index, icons_dl_list):
        if self.stop_download_flag:
            # print("Download stopped.")
            self.is_running = False
            return

         
        #📍
        # https://forums.ankiweb.net/t/add-on-support-thread-anki-leaderboard-by-shige/51634/36
        # HTTPSConnectionPool(host='shigeyuki.pythonanywhere.com', port=443): Max retries exceeded with url: /static/user_icons/ fe2e0f9c-aS15-4742-9e48-a3b53fa3cb2a.png (Caused by NameResolutionError("<urllib3.connection. HTTPSConnection object at Ox131f77a90>: Failed to resolve 'Shigeyuki.pythonanywhere.com' ([Errno 8] nodename nor Servname provided, or not known)"))

        local_image_path, image_url, user_file_name, item_pack = icons_dl_list[index]
        op = QueryOp(
            parent=self.parent,
            op=lambda col,
            local_image_path=local_image_path,
            image_url=image_url
                : self.get_icon_image(local_image_path, image_url),
            success=lambda result, index=index
                : self.on_success(index, icons_dl_list)
        )
        op.run_in_background()

    def dl_icons_in_background(self):
        if self.is_running:
            # print("Download already in progress.")
            return

        if self.icons_dl_list:
            self.is_running = True
            self.start_download(0, self.icons_dl_list)

    def on_success(self, index, icons_dl_list):
        if self.stop_download_flag:
            # print("Download stopped.")
            self.is_running = False
            return

        local_image_path, image_url, user_file_name, item_pack = icons_dl_list[index]
        tab_widget, raw_number, user_name, size = item_pack

        local_image_path, user_file_name, image_url = self.get_local_image_path(user_name)
        if os.path.exists(local_image_path):
            # 画像があればｱｲｺﾝとﾂｰﾙﾁｯﾌﾟを作る
            local_image_path, image_data = self.deobfuscate_image(local_image_path)
            new_text = f'<img src="{local_image_path}" width="{size}" height="{size}"><br>'
            # UI routines
            try:
                self.make_user_icon_and_html(tab_widget, raw_number, image_data, new_text)
            except RuntimeError:
                self.stop_download_flag = True
                # print("RuntimeError: get_icon_path_success")
                pass

        print(f"finish: {index}: {user_file_name}")

        next_index = index + 1

        while next_index < len(icons_dl_list):
            local_image_path, image_url, user_file_name, item_pack = icons_dl_list[next_index]
            if os.path.exists(local_image_path):
                # 画像があればｱｲｺﾝとﾂｰﾙﾁｯﾌﾟを作る
                tab_widget, raw_number, user_name, size = item_pack
                local_image_path, image_data = self.deobfuscate_image(local_image_path)
                new_text = f'<img src="{local_image_path}" width="{size}" height="{size}"><br>'
                try:
                    self.make_user_icon_and_html(tab_widget, raw_number, image_data, new_text)
                    print(f"Already exists: {next_index}: {user_file_name}")
                except RuntimeError:
                    self.stop_download_flag = True
                    pass
                next_index += 1
            else:
                # print(f"Processing: {next_index}: {user_file_name}")
                break

        if next_index < len(icons_dl_list):
            QTimer.singleShot(ICONS_DOWNLOAD_INTERVAL, lambda: self.start_download(next_index, icons_dl_list))
        else:
            self.is_running = False


    ### others ###

    def profile_close(self, *args, **kwargs):
        self.stop_download_flag = True
        self.icons_dl_list = []

        self.is_running = False
        self.get_path_icons_list = []
        self.is_get_path_running = False





#    ### 使ってないｱｲｺﾝを削除 ---------------------
#     def start_remove_unused_icons(self, *args, **kwargs):
#         op = QueryOp(
#             parent=self.parent,
#             op=lambda col: self.remove_unused_icons(),
#             success=lambda result: self.remove_icons_success(result)
#         )
#         op.run_in_background()

#     def remove_unused_icons(self):
#         if not self.user_icons_data:
#             return

#         # 削除しないﾌｧｲﾙ名のﾘｽﾄを作成
#         keep_files = [item[1] + '.bin' for item in self.user_icons_data]

#         if os.path.exists(self.save_directory):
#             # ﾌｫﾙﾀﾞ内のすべてのﾌｧｲﾙとｻﾌﾞﾌｫﾙﾀﾞ
#             for filename in os.listdir(self.save_directory):
#                 file_path = os.path.join(self.save_directory, filename)
#                 try:
#                     # 拡張子が.binのﾌｧｲﾙであり､user_icons_dataに含まれていないもののみを削除
#                     if os.path.isfile(file_path) and file_path.endswith('.bin') and filename not in keep_files:
#                         if 'user_files' not in file_path:
#                             return
#                         os.remove(file_path)
#                         time.sleep(1)
#                 except Exception as e:
#                     print(f'Failed to delete {file_path}. Reason: {e}')

#     def remove_icons_success(self, result):
#         pass

#     # -----------------------------------








# user_icons_downloader = IconDownloader()

# gui_hooks.profile_will_close.append(user_icons_downloader.profile_close)








    # ### Binary direct download test ### ------------
    # # !処理が遅い

    # def binary_get_icon_direct(self, tab_widget, raw_number, user_name, size):
    #     # UI routines
    #     dl_icon_interbal = 0
    #     QTimer.singleShot(
    #     dl_icon_interbal,
    #     lambda: self.bunary_run_delay(tab_widget, raw_number, user_name, size))


    # def bunary_run_delay(self, tab_widget, raw_number, user_name, size):
    #     image_url = self.user_icons_dict.get(user_name, DEFAULT_ICON_PATH)
    #     if image_url == None:
    #         return

    #     op = QueryOp(
    #         parent=mw,
    #         op=lambda col,
    #             image_url=image_url:
    #             self.binary_get_icon_image(image_url),
    #         success=lambda result:
    #             self.binary_success(tab_widget, raw_number, user_name, size, result)
    #     )
    #     if pointVersion() >= 231000:
    #         op.without_collection()
    #     op.run_in_background()

    # def binary_success(self, tab_widget, raw_number, user_name, size, result):
    #     image_data, html_image_tag = result
    #     if image_data:
    #         html_image_tag = f'<img src="{html_image_tag}" width="{size}" height="{size}"><br>'
    #         try:
    #             # UI routines
    #             dl_icon_interbal = 0
    #             QTimer.singleShot(
    #             dl_icon_interbal,
    #             lambda: self.binary_make_user_icon_and_html(tab_widget, raw_number, image_data, html_image_tag))
    #         except RuntimeError:
    #             pass
    #     else:
    #         pass

    # def binary_get_icon_image(self, image_url):
    #     response = requests.get(image_url, timeout=10)
    #     if response.status_code == 200:
    #         image_data = response.content
    #         image_base64 = base64.b64encode(image_data).decode('utf-8')
    #         html_image_tag = f'data:image/png;base64,{image_base64}'
    #         return image_data, html_image_tag
    #     return None, None


    # # ｱｲｺﾝとﾂｰﾙﾁｯﾌﾟを作る----------------
    # def binary_make_user_icon_and_html(self, tab_widget:"QTableWidget", raw_number, image_data, html_image_tag):
    #     # UI routines
    #     user_icon = None
    #     if image_data:
    #         pixmap = QPixmap()
    #         pixmap.loadFromData(image_data)
    #         user_icon = QIcon(pixmap)
    #     if not user_icon is None:
    #         user_name_item = tab_widget.item(raw_number, 1)
    #         if user_name_item is not None:
    #             user_name_item.setIcon(user_icon)
    #             self.binary_replace_text_in_tooltip(tab_widget, raw_number, html_image_tag)

    # def binary_replace_text_in_tooltip(self, tab_widget:"QTableWidget", raw_number, new_text):
    #     # UI routines
    #     column_count = tab_widget.columnCount()
    #     for column in range(column_count):
    #         item = tab_widget.item(raw_number, column)
    #         if item is not None:
    #             current_tooltip = item.toolTip()
    #             if current_tooltip:
    #                 updated_tooltip = current_tooltip.replace("<!--PLACEHOLDER-->", new_text)
    #                 item.setToolTip(updated_tooltip)
    # # --------------------------------------












# ------

# def add_user_icon_to_list(local_image_path, image_url, user_file_name):
#     global global_icons_dl_list
#     if (local_image_path, image_url, user_file_name) not in global_icons_dl_list:
#         global_icons_dl_list.append((local_image_path, image_url, user_file_name))


# def dl_icons_in_background():
#     global global_icons_dl_list
#     if global_icons_dl_list:
#         start_download(0, global_icons_dl_list)


# def start_download(index, icons_dl_list):
#     global stop_download_flag
#     if stop_download_flag:
#         print("Download stopped.")
#         return

#     local_image_path, image_url, user_file_name = icons_dl_list[index]
#     op = QueryOp(
#         parent=mw,
#         op=lambda col,
#             local_image_path=local_image_path,
#             image_url=image_url: get_icon_image(local_image_path, image_url),
#         success=lambda result,
#             index=index: on_success(index, icons_dl_list)
#     )
#     if pointVersion() >= 231000:
#         op.without_collection()
#     op.run_in_background()


# def get_icon_image(local_image_path, image_url):
#     response = requests.get(image_url)
#     if response.status_code == 200:
#         with open(local_image_path, 'wb') as file:
#             file.write(response.content)



# def on_success(index, icons_dl_list):
#     global stop_download_flag
#     if stop_download_flag:
#         print("Download stopped.")
#         return

#     local_image_path, image_url, user_file_name = icons_dl_list[index]
#     print(f"finish: {index}: {user_file_name}")
#     next_index = index + 1
#     if next_index < len(icons_dl_list):
#         time.sleep(0.1)
#         start_download(next_index, icons_dl_list)

# ------

# def get_icon_image(local_image_path, image_url):
#     response = requests.get(image_url)
#     if response.status_code == 200:
#         with open(local_image_path, 'wb') as file:
#             file.write(response.content)

# def on_success(number, local_image_path, user_file_name):
#     print(f"finish: {number}: {user_file_name}")

# def dl_icons_in_background(icons_dl_list:list):
#     # print(icons_dl_list)
#     # print("run")
#     counter = 0
#     for local_image_path, image_url, user_file_name  in icons_dl_list:
#         # if counter >= 1000:
#         #     break
#         op = QueryOp(
#             parent=mw,
#             op=lambda col, local_image_path=local_image_path, image_url=image_url: get_icon_image(local_image_path, image_url),
#             success=lambda result, number=counter, local_image_path=local_image_path, user_file_name=user_file_name: on_success(number, local_image_path, user_file_name)
#         )
#         # op.with_progress().run_in_background()
#         if pointVersion() >= 231000:
#             op.without_collection()
#         op.run_in_background()
#         counter += 1


    # tab_widget.resizeColumnsToContents()






# addon_path = dirname(__file__)
# user_file_name = re.sub(r'[<>:"/\\|?*,.\U0001F600-\U0001F64F]', '_', item)
# user_file_icon_path = join(addon_path, "media_files", "user_icons", f"{user_file_name}.png")

# if os.path.exists(user_file_icon_path):
#     user_file_icon_path = f'<img src="{user_file_icon_path}" width="{TOOLTIP_ICON_SIZE}" height="{TOOLTIP_ICON_SIZE}"><br>'
# else:
#     user_file_icon_path = None




# if not hasattr(mw, 'shige_leaderboard_count_requests'):
#     mw.shige_leaderboard_count_requests = 0

# local_image_path = None
# if mw.shige_leaderboard_count_requests < 9999:

#     import time
#     # 画像のURL
#     start_time = time.time()
#     image_url = "https://shigeyuki.pythonanywhere.com/static/user_icons/tmpwxfki_ko.png"
#     local_image_path = "downloaded_image.png"
#     end_time = time.time()
#     requests_time = end_time - start_time
#     print(f"Time taken for requests: {requests_time:.4f} seconds")


#     addon_path = dirname(__file__)

#     save_directory = join(addon_path, "media_files", "user_icons")
#     if not os.path.exists(save_directory):
#         os.makedirs(save_directory)

#     # 一時ﾌｧｲﾙに画像を保存
#     start_time = time.time()
#     user_file_name = re.sub(r'[<>:"/\\|?*,.\U0001F600-\U0001F64F]', '_', item)
#     local_image_path = file_name = os.path.join(save_directory, f"{user_file_name}.png")

#     def get_icon_image():
#         response = requests.get(image_url)
#         if response.status_code == 200:
#             with open(file_name, 'wb') as file:
#                 file.write(response.content)

#     from aqt.operations import QueryOp
#     from anki.utils import pointVersion

#     op = QueryOp(
#         parent=mw,
#         op=lambda col: get_icon_image(),
#         success= lambda result:print(f"finish {mw.shige_leaderboard_count_requests}"))
#     # op.with_progress().run_in_background()
#     if pointVersion() >= 231000:
#         op.without_collection()
#     op.run_in_background()


#     mw.shige_leaderboard_count_requests += 1