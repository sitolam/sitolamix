import shutil

# 言語ｺｰﾄﾞのﾘｽﾄ
language_codes = [
    "af", "ms", "ca", "da", "et", "eo", "eu", "gl", "hr", "it",
    "jbo", "oc", "hu", "nl", "nb", "pl", "ro", "sk", "sl", "fi",
    "sv", "tr", "zh", "ko", "cs", "el", "bg", "mn", "sr", "uk",
    "hy", "he", "ar", "th", "la", "ga", "be", "or", "tl"
]

# 元のﾌｧｲﾙﾊﾟｽ
template_file_path = "C:\\Users\\shigg\\AppData\\Roaming\\Anki2\\addons21\\Anki Leaderboard (Fixed by Shige)\\custom_shige\\translate\\translations_template.json"

# 保存先のﾃﾞｨﾚｸﾄﾘ
destination_dir = "C:\\Users\\shigg\\AppData\\Roaming\\Anki2\\addons21\\Anki Leaderboard (Fixed by Shige)\\custom_shige\\translate"

# 各言語ｺｰﾄﾞに対して.jsonﾌｧｲﾙを作成
for code in language_codes:
    destination_file_path = f"{destination_dir}\\{code}.json"
    # ﾃﾝﾌﾟﾚｰﾄﾌｧｲﾙを新しい場所にｺﾋﾟｰ
    shutil.copy(template_file_path, destination_file_path)