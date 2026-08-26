import os
import re
import json

def extract_translatable_texts(directory):
    translatable_texts = {}
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.py'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    matches = re.findall(r'_translate\("([^"]+)", "([^"]+)"\)', content)
                    for context, text in matches:
                        sanitized_text = text.replace("\\", "")
                        if context not in translatable_texts:
                            translatable_texts[context] = {}
                        # 同じﾃｷｽﾄをｷｰと値として使用
                        translatable_texts[context][sanitized_text] = sanitized_text
    
    return translatable_texts

def save_translations_to_json(translatable_texts, output_file):
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(translatable_texts, f, ensure_ascii=False, indent=4)

directory = r"C:\Users\shigg\AppData\Roaming\Anki2\addons21\Anki Leaderboard (Fixed by Shige)\forms\pyqt6UI"
translatable_texts = extract_translatable_texts(directory)

output_path = r"C:\Users\shigg\AppData\Roaming\Anki2\addons21\Anki Leaderboard (Fixed by Shige)\custom_shige\translate\translations.json"
save_translations_to_json(translatable_texts, output_path)