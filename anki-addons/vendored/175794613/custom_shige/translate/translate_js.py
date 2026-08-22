import os
import json
from googletrans import Translator # type: ignore
# pip install googletrans==3.1.0a0
# このﾊﾞｰｼﾞｮﾝ指定が必要で､私もﾊﾞｰｼﾞｮﾝ指定せずにpip installしたらｴﾗｰが発生しました｡


# 翻訳先のﾌｫﾙﾀﾞﾊﾟｽ
translate_folder = "C:\\Users\\shigg\\AppData\\Roaming\\Anki2\\addons21\\Anki Leaderboard (Fixed by Shige)\\custom_shige\\translate"

# Google翻訳APIの初期化
translator = Translator()

# 除外するﾌｧｲﾙ名のﾘｽﾄ
exclude_files = ["translations_template.json", "ja.json"
# here
]


### これらは翻訳きない #
# "jbo.json"  # Lojban
# "oc.json",   # Occitan
########################


# これらは翻訳の言語ｺｰﾄﾞが違う
# 言語ｺｰﾄﾞのﾏｯﾋﾟﾝｸﾞを定義
language_codes = {
    "nb": "no",    # Norwegian Bokmål
    "zh": "zh-CN"     # Simplified Chinese
}

# 翻訳するﾌｧｲﾙ名のﾘｽﾄを定義（空の場合はすべてのﾌｧｲﾙを翻訳）
translate_files = []  # 例: ['nb.json', 'zh.json']


# ﾌｫﾙﾀﾞ内のすべての.jsonﾌｧｲﾙを取得
for filename in os.listdir(translate_folder):
    # ﾌｧｲﾙ名の指定がある場合は一致するﾌｧｲﾙのみ､指定がない場合はすべてのﾌｧｲﾙを翻訳
    if filename.endswith(".json") and (filename in translate_files or not translate_files) and filename not in exclude_files:
        print(filename)
        # ﾌｧｲﾙの完全ﾊﾟｽを取得
        file_path = os.path.join(translate_folder, filename)
        # 言語ｺｰﾄﾞをﾌｧｲﾙ名から抽出
        language_code = filename.split('.')[0]

        # 正確な言語ｺｰﾄﾞを取得
        language_code = language_codes.get(language_code, language_code)

        # JSONﾌｧｲﾙを読み込む
        with open(file_path, 'r', encoding='utf-8') as file:
            data = json.load(file)

        # 各ｷｰの値を翻訳（辞書型の場合のみ）
        translated_data = {}
        for key, value in data.items():
            if isinstance(value, dict):  # 値が辞書型の場合
                translated_value = {}
                for sub_key, sub_value in value.items():
                    # 辞書内の値を翻訳
                    translated_text = translator.translate(sub_value, dest=language_code).text
                    translated_value[sub_key] = translated_text
                translated_data[key] = translated_value
            else:
                # 辞書型でない場合は翻訳しない
                translated_data[key] = value

        # 翻訳されたﾃﾞｰﾀでJSONﾌｧｲﾙを上書き
        with open(file_path, 'w', encoding='utf-8') as file:
            json.dump(translated_data, file, ensure_ascii=False, indent=4)
