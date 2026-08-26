import os
import zipfile
from datetime import datetime

def create_ankiaddon():
    # 現在のﾃﾞｨﾚｸﾄﾘを取得
    current_dir = os.getcwd()

    today = datetime.today().strftime('%Y%m%d%H%M')

    # Zipﾌｧｲﾙ名
    zip_name = f'addon_{today}.zip'

    # 除外するﾌｫﾙﾀﾞと拡張子とﾌｧｲﾙ名
    exclude_dirs = ['__pycache__', 'bundle03', '.vscode']
    # exclude_dirs = ['__pycache__', 'bundle03', 'user_files', '.vscode']
    exclude_exts = ['.ankiaddon']
    exclude_files = ['meta.json', zip_name, "template_00.md"]

    # Zipﾌｧｲﾙを作成
    with zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(current_dir):
            # 除外するﾌｫﾙﾀﾞを除外
            dirs[:] = [d for d in dirs if d not in exclude_dirs]
            for file in files:
                # 指定したﾌｧｲﾙ名と拡張子を除外
                if file not in exclude_files and os.path.splitext(file)[1] not in exclude_exts:
                    zipf.write(os.path.join(root, file),
                                os.path.relpath(os.path.join(root, file),
                                                current_dir))  # 親ﾃﾞｨﾚｸﾄﾘ名を除去

    # 拡張子を .ankiaddon に変更
    os.rename(zip_name, f'addon_{today}.ankiaddon')

# ｽｸﾘﾌﾟﾄを実行
create_ankiaddon()