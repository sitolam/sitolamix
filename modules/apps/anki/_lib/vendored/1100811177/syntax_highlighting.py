from genericpath import isfile
import json
import os
import sys

from bs4 import BeautifulSoup

import aqt
from aqt.qt import *
from .anki_version_detection import anki_point_version
if anki_point_version >= 24:
    from aqt.gui_hooks import (
        editor_will_load_note,
    )
if anki_point_version >= 50:
    from aqt.gui_hooks import (
        editor_did_init_buttons,
        editor_will_show_context_menu,
        profile_did_open,
        theme_did_change,
    )
from aqt import mw
from aqt.utils import showInfo, showWarning, tooltip
from anki.hooks import addHook

from .config import gc, wc
from .fuzzy_panel import FilterDialog
from .pygments_helper import (
    LANG_MAP,
    pyg__highlight,
    pyg__get_lexer_by_name,
    pyg__HtmlFormatter,
    pyg__ClassNotFound,
)
from .settings_dialog import ConfigWindowMain
from .supplementary import wrap_in_tags


############################################
########## gui config and auto loading #####

def set_some_paths():
    global addon_path
    global addon_folder_name
    global addon_name
    global css_templates_folder
    global media_folder
    global css_file_in_media_for_rest_path
    global css_file_in_media_for_editor_name
    global css_file_in_media_for_editor_path
    global path_editor_css_in_injector
    addon_path = os.path.dirname(__file__)
    addon_folder_name = os.path.basename(addon_path)
    addon_name = mw.addonManager.addonName(addon_folder_name)
    css_templates_folder = os.path.join(addon_path, "css")
    media_folder = os.path.join(mw.pm.profileFolder(), "collection.media")
    css_file_in_media_for_rest_name = "_styles_for_syntax_highlighting.css"
    css_file_in_media_for_rest_path = os.path.join(media_folder, css_file_in_media_for_rest_name)
    css_file_in_media_for_editor_name = "_styles_for_syntax_highlighting_editor.css"
    css_file_in_media_for_editor_path = os.path.join(media_folder, css_file_in_media_for_editor_name)
    path_editor_css_in_injector = os.path.join(mw.pm.addonFolder(), "181103283", "user_files", "field_syntax_highlighting.css")
if anki_point_version <= 49:
    addHook("profileLoaded", set_some_paths)
else:
    profile_did_open.append(set_some_paths)


insertscript = """<script>
function MyInsertHtml(content) {
    var s = window.getSelection();
    var r = s.getRangeAt(0);
    r.collapse(true);
    var mydiv = document.createElement("div");
    mydiv.innerHTML = content;
    r.insertNode(mydiv);
    // Move the caret
    r.setStartAfter(mydiv);
    r.collapse(true);
    s.removeAllRanges();
    s.addRange(r);
}
</script>
"""

# only for <41:
def add_style_to_editor_html_for_up_to_40():
    editor_style = ""
    if os.path.isfile(css_file_in_media_for_editor_path):
        with open(css_file_in_media_for_editor_path, "r") as css_file:
            css = css_file.read()
            editor_style = "<style>\n{}\n</style>".format(css.replace("%", "%%"))
    aqt.editor._html = editor_style + insertscript + aqt.editor._html


# for 42-49:
# https://github.com/ijgnd/anki__editor__apply__font_color__background_color__custom_class__custom_style/commit/8cfea36d0077e33c31045b7f64dee5eeeaca86a6
def append_css_to_Editor__42_49(js, note, editor) -> str:
    newjs = ""
    if os.path.isfile(css_file_in_media_for_editor_path):
        with open(css_file_in_media_for_editor_path, "r") as css_file:
            css = css_file.read()
            newjs = """
var userStyle = document.createElement("style");
userStyle.rel = "stylesheet";
userStyle.textContent = `USER_STYLE`;
userStyle.id = "syntax_highlighting_fork";
forEditorField([], (field) => {
    var sr = field.editingArea.shadowRoot;
    var syntax_highlighting_fork = sr.getElementById("syntax_highlighting_fork");
    if (syntax_highlighting_fork) {
        syntax_highlighting_fork.parentElement.replaceChild(userStyle, syntax_highlighting_fork)
    }
    else {
        sr.insertBefore(userStyle.cloneNode(true), field.editingArea.editable)
    }
});
        """.replace("USER_STYLE", css)
    return js + newjs


if anki_point_version < 41:
    addHook("profileLoaded", add_style_to_editor_html_for_up_to_40)
elif anki_point_version <= 49:
    editor_will_load_note.append(append_css_to_Editor__42_49)
elif 50 <= anki_point_version <= 54:
    # use add-on css-injector by kleinerpirat
    # my add-on version from 2022-01 reused code from an onld version of css-injector which seems to have worked
    # back then ... but that's no longer true.
    def show_needed_addons_message_once():
        msg = """
This is a one time message by the add-on "ADDONNAME".

This message is only relevant for Anki versions 2.1.50 - 2.1.54. For older
and newer versions this add-on automatically applies styling for source code to the
editor.

For Anki 2.1.50-2.1.54 you must install the add-on "CSS Injector - Change default editor styles",
https://ankiweb.net/shared/info/181103283. Then you must modify it by adding one line into one
file of this add-on.

If css injector gets updates you'd have to repeat this. But "CSS Injector" shouldn't get too
many updates since Anki 2.1.55 now makes it easy to load css into the editor.

Open the file "181103283/web/injector.js" in an editor.

Then below the line 105 which is 

    injectStylesheet(root, editable, `/_addons/${addonPackage}/user_files/field.css`);

insert the new line

    injectStylesheet(root, editable, `/_addons/${addonPackage}/user_files/field_syntax_highlighting.css`);

Then restart Anki.

You can also read this guide on the ankiweb listing for the add-on "ADDONNAME".
"""
        msg_adjusted = msg.replace("\n\n", "ÄÖÜ").replace("\n", " ").replace("ÄÖÜ", "\n").replace("ADDONNAME", addon_name)
        #showInfo(msg_adjusted, textFormat="plain", title=f"Anki Add-on: {addon_name}", type="critical")

        if not gc("one_time_info_for_50_54_shown"):
            from .dialog_text_display import Text_Displayer
            td = Text_Displayer(
                parent=mw,
                text=msg_adjusted,
                windowtitle=f"Anki Add-on: {addon_name}",
            )
            td.resize(800, 400)  # width, height
            td.exec()
            wc("one_time_info_for_50_54_shown", True)
    profile_did_open.append(show_needed_addons_message_once)
else:  # 2.1.55 Beta 1+
    # https://github.com/ijgnd/anki__editor__apply__font_color__background_color__custom_class__custom_style/blob/b2a5697c3d9030932abe89ba9fa153a2796116ee/src/editor/webview.py#L3
    def append_css_to_Editor(js, note, editor) -> str:
        return (
            js
            + f"""
    require("anki/RichTextInput").lifecycle.onMount(async ({{ customStyles }}) => {{
        const {{ addStyleTag }} = await customStyles;
        const {{ element: styleTag }} = await addStyleTag('customStyles');
        styleTag.textContent = `{editor_css}`
    }});
    """
        )
    editor_will_load_note.append(append_css_to_Editor)
    def set_global_css_var():
        global editor_css
        style = gc("style_nm") if aqt.theme.theme_manager.get_night_mode() else gc("style")
        editor_css = css_for_style(style)
    def remove_styling_helper_for_50_54():
        if os.path.isfile(path_editor_css_in_injector):
            os.remove(path_editor_css_in_injector)
    profile_did_open.append(remove_styling_helper_for_50_54)
    profile_did_open.append(set_global_css_var)
    





def update_card_templates():
    for m in mw.col.models.all():
        if True:  # if m['name'] in template_name_list:
            # https://github.com/trgkanki/cloze_hide_all/issues/43
            lines = [
                """@import url("_styles_for_syntax_highlighting.css");""",
                """@import url(_styles_for_syntax_highlighting.css);""",
            ]
            for l in lines:
                if l in m['css'] or "/*syntax_highlighting_dont_add_styles_file*/" in m['css'] or "/* syntax_highlighting_dont_add_styles_file */" in m['css']:
                    break
            else:
                model = mw.col.models.get(m['id'])
                model['css'] = l + "\n\n" + model['css']
                mw.col.models.save(model)
if anki_point_version <= 49:
    addHook("profileLoaded", update_card_templates)
else:
    profile_did_open.append(update_card_templates)



def css_for_style(style):
    template_file = os.path.join(css_templates_folder, style + ".css")
    with open(template_file) as f:
        css = f.read()
    my_css = """
.highlight {
    text-align:left;
    font-family: %s;
    padding-left: 5px;
    padding-right: 5px;
    color: black;
  }

.highlight code {
    font-family: %s;
  }

.highlight pre {
    font-family: %s;
  }

"""
    css = css.replace("pre { line-height: 125%; }", my_css)
    font = gc("font", "Droid Sans Mono")
    css = css % (font, font, font)
    if gc('centerfragments'):
        css += """\ntable.highlighttable("margin: 0 auto;")\n"""
    return css


injector_addon_installed = None
have_checked_for_injector_addon = None
def check_for_injector_addon():
    global injector_addon_installed
    global check_for_injector_addon
    try:
        injector_addon_installed = __import__("181103283")
    except:
        tooltip(f"The addon {addon_name} does not work without the add-on 'CSS Injector'. Install it and restart Anki.", period=10000)
    have_checked_for_injector_addon = True


def write_css_to_file_and_global_var_for_current_theme():
    global editor_css
    # one file with both styles is needed for the card templates preview where I can toggle between
    # night mode enabled and disabled
    # But this doesn't work in the editor. Though the body has the nightMode and night_mode class 
    # just using ".nightMode .highlight" is not enough. It's quicker for me to just use an extra
    # file. TODO Use better css so that I can go back to one file ...
    css_day = css_for_style(gc("style"))
    # https://docs.ankiweb.net/templates/styling.html#night-mode
    css_nm = css_for_style(gc("style_nm")).replace(".highlight", ".nightMode .highlight")
    with open(css_file_in_media_for_rest_path, "w") as f:
        f.write(f"{css_day}\n\n\n{css_nm}")
    style = gc("style_nm") if aqt.theme.theme_manager.get_night_mode() else gc("style")
    editor_css = css_for_style(style)
    with open(css_file_in_media_for_editor_path, "w") as f:
        f.write(css_for_style(style))
    if 50 <= anki_point_version <= 54:
        if not have_checked_for_injector_addon:
            check_for_injector_addon()
        if injector_addon_installed:
            with open(path_editor_css_in_injector, "w") as f:
                f.write(css_for_style(style))
if anki_point_version <= 49:
    addHook("profileLoaded", write_css_to_file_and_global_var_for_current_theme)
else:
    profile_did_open.append(write_css_to_file_and_global_var_for_current_theme)
    theme_did_change.append(write_css_to_file_and_global_var_for_current_theme)


def on_settings():
    one_time_info_for_50_54_shown = gc("one_time_info_for_50_54_shown")
    dialog = ConfigWindowMain(mw, mw.addonManager.getConfig(__name__))
    dialog.activateWindow()
    dialog.raise_()
    if dialog.exec():
        dialog.config["one_time_info_for_50_54_shown"] = one_time_info_for_50_54_shown
        mw.addonManager.writeConfig(__name__, dialog.config)
        # wc("one_time_info_for_50_54_shown", one_time_info_for_50_54_shown)
        mw.progress.start(immediate=True)
        update_card_templates()
        write_css_to_file_and_global_var_for_current_theme()
        mw.progress.finish()
        showInfo("You need to restart Anki so that all changes take effect.")
mw.addonManager.setConfigAction(__name__, on_settings)


#######END gui config and auto loading #####
############################################


ERR_LEXER = ("<b>Error</b>: Selected language not found.<br>"
             "A common source of errors: When you update the add-on Anki keeps your user settings"
             " but an update of the add-on might include a new version of the Pygments library"
             " which sometimes renames languages. This means a setting that used to work no longer"
             " works with newer versions of this add-on.")

ERR_STYLE = ("<b>Error</b>: Selected style not found.<br>"
             "A common source of errors: When you update the add-on Anki keeps your user settings"
             " but an update of the add-on might include a new version of the Pygments library"
             " which sometimes renames languages. This means a setting that used to work no longer"
             " works with newer versions of this add-on.")

LASTUSED = ""


def show_error(msg, parent):
    showWarning(msg, title="Code Formatter Error", parent=parent)


def get_deck_name(editor):
    if isinstance(editor.parentWindow, aqt.addcards.AddCards):
        return editor.parentWindow.deckChooser.deckName()
    elif isinstance(editor.parentWindow, (aqt.browser.Browser, aqt.editcurrent.EditCurrent)):
        return mw.col.decks.name(editor.card.did)
    else:
        return None  # Error


def get_default_lang(editor):
    lang = gc('defaultlang')
    if gc('defaultlangperdeck'):
        deck_name = get_deck_name(editor)
        if deck_name and deck_name in gc('deckdefaultlang'):
            lang = gc('deckdefaultlang')[deck_name]
    return lang


def hilcd(ed, code, langAlias):
    global LASTUSED
    linenos = gc('linenos')
    centerfragments = gc('centerfragments')
    
    noclasses = not gc('cssclasses')
    if noclasses:
        msg = ("The version from 2021-03 only applies the styling with classes and no longer "
               "supports applying inline styling (the old default).\nThe reason is twofold: "
               "It seems as if loading custom css into the editor will soon be officially "
               "supported, see https://github.com/ankitects/anki/pull/1049. This also reduces "
               "the add-on complexity.\nIf you don't like this change you could use the "
               "original Syntax Highlighting add-on.\nTo avoid seeing this info open the "
               "add-on config once and save it."
        )
        showInfo(msg)
        noclasses = False

    try:
        my_lexer = pyg__get_lexer_by_name(langAlias, stripall=not gc("remove leading spaces if possible", True))
    except pyg__ClassNotFound as e:
        print(e)
        print(ERR_LEXER)
        show_error(ERR_LEXER, parent=ed.parentWindow)
        return False
    try:
        # http://pygments.org/docs/formatters/#HtmlFormatter
        my_formatter = pyg__HtmlFormatter(
            # cssclass=css_class,
            font_size=16,
            linenos=linenos, 
            lineseparator="<br>",
            nobackground=False,  # True would solve night mode problem without any config (as long as no line numbers are used)
            noclasses=noclasses,
            style=gc("style"),
            wrapcode=True)
    except pyg__ClassNotFound as e:
        print(e)
        print(ERR_STYLE)
        show_error(ERR_STYLE, parent=ed.parentWindow)
        return False

    pygmntd = pyg__highlight(code, my_lexer, my_formatter).rstrip()
    if linenos:
        pretty_code = pygmntd + "<br>"
    else:
        pretty_code = "".join([f'<table style="text-align: left;" class="highlighttable"><tbody><tr><td>',
                                pygmntd,
                                "</td></tr></tbody></table><br>"])

    if centerfragments:
        soup = BeautifulSoup(pretty_code, 'html.parser')
        tablestyling = "margin: 0 auto;"
        for t in soup.findAll("table"):
            if t.has_attr('style'):
                t['style'] = tablestyling + t['style']
            else:
                t['style'] = tablestyling
        pretty_code = str(soup)

    ed.web.eval(f"setFormat('inserthtml', {json.dumps(pretty_code)});")
    LASTUSED = langAlias


basic_stylesheet = """
QMenu::item {
    padding-top: 16px;
    padding-bottom: 16px;
    padding-right: 75px;
    padding-left: 20px;
    font-size: 15px;
}
QMenu::item:selected {
    background-color: #fd4332;
}
"""


class keyFilter(QObject):
    def __init__(self, parent):
        super().__init__(parent)
        self.parent = parent

    def eventFilter(self, obj, event):
        if event.type() == QEvent.Type.KeyPress:
            if event.key() == Qt.Key.Key_Space:
                self.parent.alternative_keys(self.parent, Qt.Key.Key_Return)
                return True
            elif event.key() == Qt.Key.Key_T:
                self.parent.alternative_keys(self.parent, Qt.Key.Key_Left)
                return True
            elif event.key() == Qt.Key.Key_B:
                self.parent.alternative_keys(self.parent, Qt.Key.Key_Down)
                return True
            elif event.key() == Qt.Key.Key_G:
                self.parent.alternative_keys(self.parent, Qt.Key.Key_Up)
                return True
            # elif event.key() == :
            #     self.parent.alternative_keys(self.parent, Qt.Key.Key_Right)
            #     return True
        return False


def alternative_keys(self, key):
    # https://stackoverflow.com/questions/56014149/mimic-a-returnpressed-signal-on-qlineedit
    keyEvent = QKeyEvent(QEvent.KeyPress, key, Qt.KeyboardModifier.NoModifier)
    QCoreApplication.postEvent(self, keyEvent)


def on_all(editor, code):
    d = FilterDialog(editor.parentWindow, LANG_MAP)
    if d.exec():
        hilcd(editor, code, d.selvalue)


def illegal_info(val):
    msg = ('Illegal value ("{}") in the config of the add-on {}.\n'
           "A common source of errors: When you update the add-on Anki keeps your "
           "user settings but an update of the add-on might include a new version of "
           "the Pygments library which sometimes renames languages. This means a "
           "setting that used to work no longer works with newer versions of this "
           "add-on.".format(val, addon_name))
    showInfo(msg)


def remove_leading_spaces(code):
    #https://github.com/hakakou/syntax-highlighting/commit/f5678c0e7dfeb926a5d7f0b780d8dce6ffeaa9d9
    
    # Search in each line for the first non-whitespace character,
    # and calculate minimum padding shared between all lines.
    lines = code.splitlines()
    starting_space = sys.maxsize

    for l in lines:
        # only interested in non-empty lines
        if len(l.strip()) > 0:
            # get the index of the first non whitespace character
            s = len(l) - len(l.lstrip())
            # is it smaller than anything found?
            if s < starting_space:
                starting_space = s

    # if we found a minimum number of chars we can strip off each line, do it.
    if (starting_space < sys.maxsize):
        code = '';    
        for l in lines:
            code = code + l[starting_space:] + '\n'
    return code



'''
Notes about wrapping with pre or code

pre is supposed to be "preformatted text which is to be presented exactly as written 
in the HTML file.", https://developer.mozilla.org/en-US/docs/Web/HTML/Element/pre, 


there are some differences: pre is a block element, see https://www.w3schools.com/html/html_blocks.asp
so code is an inline element, then I could use the "Custom Styles" add-on,
https://ankiweb.net/shared/info/1899278645 to apply the code tag?


### "Mini Format Pack supplementary" approach, https://ankiweb.net/shared/info/476705431?
# wrap_in_tags(editor, code, "pre")) 
# wrap_in_tags(editor, code, "code"))
# My custom version depends on deleting the selection first



### combine execCommands delete and insertHTML
# I remove the selection when opening the helper menu
#     editor.web.evalWithCallback("document.execCommand('delete');", lambda 
#                                 _, e=editor, c=code: _openHelperMenu(e, c, True))
# then in theory this should work:
#   editor.web.eval(f"""document.execCommand('insertHTML', false, %s);""" % json.dumps(code))
# but it often doesn't work in Chrome
# e.g.
#      code = f"<table><tbody><tr><td><pre>{code}</pre></td></tr></tbody></table>"  # works
#      code = f"<p><pre>{code}</pre></p>"  # doesn't work
#      code = f'<pre id="{uuid.uuid4().hex}">{code}</pre>'  # doesn't work
#      code = f'<pre style="" id="{uuid.uuid4().hex}">{code}</pre>'  # doesn't work
#      code = '<pre class="shf_pre">' + code + "</pre>"  # doesn't work
#      code = '<div class="city">' + code + "</div>"     # doesn't work
#      code = """<span style=" font-weight: bold;">code </span>"""  # works
#      code = """<div style=" font-weight: bold;">code </div>"""  # partially: transformed into span?
# That's a known problem, see https://stackoverflow.com/questions/25941559/is-there-a-way-to-keep-execcommandinserthtml-from-removing-attributes-in-chr
# The top answer is to use a custom js inserter function


### MiniFormatPack approach
#     editor.web.eval("setFormat('formatBlock', 'pre')")
# setFormat is a thin Anki wrapper around document.execCommand
# but this formats the whole paragraph and not just the selection


### idea: move the selection to a separate block first. Drawback: in effect there's no undo
# undo in contenteditable is hard, works best if I just use document.execCommand, i.e.
# setFormat. So I have to decide what's more important for me, I think undo is more important


At the moment my version of the MiniFormatSupplementary mostly works so I keep it.
'''


def _open_helper_menu(editor, code, selected_text):
    global LASTUSED

    if gc("remove leading spaces if possible", True):
        code = remove_leading_spaces(code)

    menu = QMenu(editor.widget)
    menu.setStyleSheet(basic_stylesheet)
    # add small info if pasting
    label = QLabel("selection" if selected_text else "paste")
    action = QWidgetAction(editor.widget)
    action.setDefaultWidget(label)
    menu.addAction(action)

    menu.alternative_keys = alternative_keys
    kfilter = keyFilter(menu)
    menu.installEventFilter(kfilter)

    if gc("show pre/code", False):
        # TODO: Do I really need the custom code, couldn't I just wrap in newer versions
        # as with the mini format pack, see https://github.com/glutanimate/mini-format-pack/pull/13/commits/725bb8595631e4dbc56bf881427aeada848e43c9
        m_pre = menu.addAction("&unformatted (<pre>)")
        m_pre.triggered.connect(lambda _, a=editor, c=code: wrap_in_tags(a, c, tag="pre", class_name="shf_pre"))
        m_cod = menu.addAction("unformatted (<&code>)")
        m_cod.triggered.connect(lambda _, a=editor, c=code: wrap_in_tags(a, c, tag="code", class_name="shf_code"))

    defla = get_default_lang(editor)
    if defla in LANG_MAP:
        d = menu.addAction("&default (%s)" % defla)
        d.triggered.connect(lambda _, a=editor, c=code: hilcd(a, c, LANG_MAP[defla]))
    else:
        d = False
        illegal_info(defla)
        return
    
    if LASTUSED:
        l = menu.addAction("l&ast used")
        l.triggered.connect(lambda _, a=editor, c=code: hilcd(a, c, LASTUSED))

    favmenu = menu.addMenu('&favorites')
    favfilter = keyFilter(favmenu)
    favmenu.installEventFilter(favfilter)
    favmenu.alternative_keys = alternative_keys

    a = menu.addAction("&select from all")
    a.triggered.connect(lambda _, a=editor, c=code: on_all(a, c))
    for e in gc("favorites"):
        if e in LANG_MAP:
            a = favmenu.addAction(e)
            a.triggered.connect(lambda _, a=editor, c=code, l=LANG_MAP[e]: hilcd(a, c, l))
        else:
            illegal_info(e)
            return

    if d:
        menu.setActiveAction(d)
    menu.exec(QCursor.pos())


def open_helper_menu(editor):
    selected_text = editor.web.selectedText()
    if selected_text:
        #  Sometimes, self.web.selectedText() contains the unicode character
        # '\u00A0' (non-breaking space). This character messes with the
        # formatter for highlighted code.
        code = selected_text.replace('\u00A0', ' ')
        editor.web.evalWithCallback("document.execCommand('delete');", lambda 
                                    _, e=editor, c=code: _open_helper_menu(e, c, True))
    else:
        clipboard = QApplication.clipboard()
        code = clipboard.text()
        _open_helper_menu(editor, code, False)


def make_editor_context_menu_entry(ewv, menu):
    e = ewv.editor
    a = menu.addAction("Syntax Highlighting")
    a.triggered.connect(lambda _, ed=e: open_helper_menu(ed))
if anki_point_version <= 49:
    addHook('EditorWebView.contextMenuEvent', make_editor_context_menu_entry)
else:
    editor_will_show_context_menu.append(make_editor_context_menu_entry)



def keystr(k):
    key = QKeySequence(k)
    return key.toString(QKeySequence.SequenceFormat.NativeText)


def add_editor_button(buttons, editor):
    b = editor.addButton(
        os.path.join(addon_path, "icons", "button.png"),
        "syhl_linkbutton",
        open_helper_menu,
        tip="Syntax Highlighting for code ({})".format(keystr(gc("hotkey", ""))),
        keys=gc("hotkey", "")
        )
    buttons.append(b)
    return buttons
if anki_point_version <= 49:
    addHook("setupEditorButtons", add_editor_button)
else:
    editor_did_init_buttons.append(add_editor_button)