
import json
import os
from time import sleep
from aqt import gui_hooks

try:
    from anki.lang import current_lang
except:
    current_lang = "en"


# この翻訳ﾌｧｲﾙはQtﾃﾞｻﾞｲﾅｰで作成した.pyﾌｧｲﾙを直接編集して追加する
    # from PyQt6 import QtCore, QtGui, QtWidgets
    # from ...custom_shige.searchable_combobox import SearchableComboBox
    # QtWidgets.QComboBox = SearchableComboBox # add
    # from ...custom_shige.translate.translate import ShigeTranslator
    # QtCore.QCoreApplication.translate = ShigeTranslator.translate


class ShigeTranslator:
    language = current_lang
    translations = {}
    skip_keys = [
        "Global",
        "Friends",
        "Country",
        "Group",
        "League",
        "Reviews",
        "Time",
        "Streak",
        "Reviews past 31 days",
        "Retention",
    ]

    @classmethod
    def load_translations_for_language(cls, lang):
        addon_path = os.path.dirname(__file__)
        file_path = os.path.join(addon_path,f"{lang}.json")
        if os.path.exists(file_path):
            with open(file_path, 'r', encoding='utf-8') as file:
                cls.translations[lang] = json.load(file)
        else:
            print(f"Warning: {file_path} not found. Falling back to default translations.")

    @classmethod
    def set_language(cls): # 設定変更には再起動が必要
        global current_lang
        cls.language = current_lang.split('-')[0]
        cls.load_translations_for_language(cls.language)

    @classmethod
    def translate(cls, context, text):
        if text in cls.skip_keys:
            return text
        # 現在の言語設定に基づいて翻訳を取得
        lang_translations = cls.translations.get(cls.language, {})
        context_translations = lang_translations.get(context, {})
        return context_translations.get(text, text)

ShigeTranslator.set_language()

# gui_hooks.dialog_manager_did_open_dialog



        # "Global": "Global",
        # "Friends": "Friends",
        # "Country": "Country",
        # "Group": "Group",
        # "League": "League",
        # "Reviews": "Reviews",
        # "Time": "Time",
        # "Streak": "Streak",
        # "Reviews past 31 days": "Reviews past 31 days",
        # "Retention": "Retention",







    # def __getattribute__(self, name):
    #     attr = super().__getattribute__(name)
    #     global current_lang
    #     if isinstance(attr, dict):
    #         current_lang = current_lang.split('-')[0]
    #         return attr.get(current_lang)
    #     else:
    #         return super().__getattribute__(name)



# shige_tr = LanguageManager()


# "jbo.json"
# "nb.json",
# "oc.json",
# zh.json
# LO_JBOBAU_JBO = "jbo" # Lojban
# NORSK_NB = "nb" # Norwegian Bokmål
# LENGA_DOC_OC = "oc" # Occitan
# SIMPLIFIED_CHINESE_ZH = "zh" # Simplified Chinese

# ENGLISH_EN = "en" # English
# JAPANESE_JA = "ja" # Japanese
# PORTUGUES_PT = "pt" # Portuguese
# DEUTSCH_DE = "de" # German
# FRANCAIS_FR = "fr" # French
# PERSIAN_FA = "fa" # Persian
# RUSSIAN_RU = "ru" # Russian
# ESPANOL_ES = "es" # Spanish
# TIENG_VIET_VI = "vi" # Vietnamese
# # -----------
# AFRIKAANS_AF = "af" # Afrikaans
# BAHASA_MELAYU_MS = "ms" # Malay
# CATALA_CA = "ca" # Catalan
# DANSK_DA = "da" # Danish
# EESTI_ET = "et" # Estonian
# ESPERANTO_EO = "eo" # Esperanto
# EUSKARA_EU = "eu" # Basque
# GALEGO_GL = "gl" # Galician
# HRVATSKI_HR = "hr" # Croatian
# ITALIANO_IT = "it" # Italian
# LO_JBOBAU_JBO = "jbo" # Lojban
# LENGA_DOC_OC = "oc" # Occitan
# MAGYAR_HU = "hu" # Hungarian
# NEDERLANDS_NL = "nl" # Dutch
# NORSK_NB = "nb" # Norwegian Bokmål
# POLSKI_PL = "pl" # Polish
# ROMANA_RO = "ro" # Romanian
# SLOVENCINA_SK = "sk" # Slovak
# SLOVENSCINA_SL = "sl" # Slovenian
# SUOMI_FI = "fi" # Finnish
# SVENSKA_SV = "sv" # Swedish
# TURKCE_TR = "tr" # Turkish
# SIMPLIFIED_CHINESE_ZH = "zh" # Simplified Chinese
# KOREAN_KO = "ko" # Korean
# CESTINA_CS = "cs" # Czech
# HELLENIC_EL = "el" # Greek
# BULGARIAN_BG = "bg" # Bulgarian
# MONGOL_MN = "mn" # Mongolian
# SERBIAN_SR = "sr" # Serbian
# UKRAINIAN_UK = "uk" # Ukrainian
# ARMENIAN_HY = "hy" # Armenian
# HEBREW_HE = "he" # Hebrew
# ARABIC_AR = "ar" # Arabic
# THAI_TH = "th" # Thai
# LATIN_LA = "la" # Latin
# IRISH_GA = "ga" # Irish
# BELARUSIAN_BE = "be" # Belarusian
# ODIA_OR = "or" # Odia
# FILIPINO_TL = "tl" # Filipino