import os

# 著作権ﾍｯﾀﾞｰの定義
header = """
# Anki Leaderboard
# Copyright (C) 2020 - 2024 Thore Tyborski <https://github.com/ThoreBor>
# Copyright (C) 2024 Shigeyuki <http://patreon.com/Shigeyuki>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""

# ﾌｧｲﾙを探すﾃﾞｨﾚｸﾄﾘのﾊﾟｽ
directory = os.getcwd()
# print(directory)

# 除外するﾌｧｲﾙ名とﾌｫﾙﾀﾞ名のﾘｽﾄ
exclude_files = ['zzz_makeAnkiAddonFile.py', 'popup_config.py','add_lisence.py','path_manager.py']
exclude_folders = ['shige_pop', 'custom_shige']

# ﾃﾞｨﾚｸﾄﾘ内のすべてのﾌｧｲﾙを走査
for foldername, subfolders, filenames in os.walk(directory):
    # 除外するﾌｫﾙﾀﾞをｽｷｯﾌﾟ
    if any(exclude_folder in foldername for exclude_folder in exclude_folders):
        continue

    for filename in filenames:
        # 除外するﾌｧｲﾙをｽｷｯﾌﾟ
        if filename in exclude_files:
            continue

        # .py ﾌｧｲﾙのみを対象とする
        if filename.endswith('.py'):
            filepath = os.path.join(foldername, filename)

            # ﾌｧｲﾙを読み込む
            with open(filepath, 'r+', encoding='utf-8') as f:
                content = f.read()

                # Qt Designerで生成されたﾌｧｲﾙをｽｷｯﾌﾟ
                if 'PyQt5 UI code generator' in content or 'PyQt6 UI code generator' in content:
                    continue

                # ﾍｯﾀﾞｰがすでに存在する場合はｽｷｯﾌﾟ
                if content.startswith(header.lstrip('\n')):
                    continue

                print(filepath)

                # ﾍｯﾀﾞｰを追加
                f.seek(0, 0)
                f.write(header.lstrip('\n') + '\n' + content)