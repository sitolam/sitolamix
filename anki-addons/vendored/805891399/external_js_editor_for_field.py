import os

from bs4 import BeautifulSoup

from anki.hooks import addHook
from aqt import mw
from aqt.qt import QKeySequence
from aqt.theme import theme_manager
from aqt.utils import tooltip

from .config import gc
from .dialog import ExtraWysiwygEditorForField
from .helpers import (
    addonfoldername,
    addon_path,
    hiliters_tinymce,
    maybe_pre_process_html,
    readfile,
    user_files_folder,
)

if os.path.isfile(os.path.join(user_files_folder, "additional_editors.py")):
    from .user_files.additional_editors import additional_editors_dict
else:
    additional_editors_dict = {}


if os.path.isfile(os.path.join(user_files_folder, "additional_buttons_menuentries.py")):
    from .user_files.additional_buttons_menuentries import get_additional_arglist
else:
    def get_additional_arglist():
        return []


mw.addonManager.setWebExports(__name__, r"((user_files[/\\])?web[/\\].*)")


def internal_images_to_file(editor, html):
    if "data:image/" in html:
        soup = BeautifulSoup(html, "html.parser")
        for img in soup.find_all("img", src=lambda src: src.startswith("data:image/")):
            try:
                src = img["src"]
            except KeyError:
                continue        
            else:
                img['src'] = editor.inlinedImageToFilename(src)
        html = str(soup)
    return html


def download_external_images(editor, html):
    soup = BeautifulSoup(html, "html.parser")
    for img in soup.find_all("img"):
        try:
            src = img["src"]
        except KeyError:
            continue        
        else:
            if editor.isURL(src):
                fname = editor._retrieveURL(src)
                if fname:
                    img["src"] = fname
    html = str(soup)
    return html


def editor_update_field(editor):
    if not hasattr(editor, "edited_field_content") or not isinstance(
        editor.edited_field_content, str
    ):
        tooltip("Unknown error in Add-on. Aborting ...")
        return

    html = editor.edited_field_content
    # pasting images into TinyMCE6 creates inline images which in turn slow down Anki
    # see e.g. https://forums.ankiweb.net/t/anki-browse-extremely-laggy/32533/8
    if gc("use Anki's built-in html processing"):
        # the following should convert inline images, save external images and remove some
        # problematic tags and it should work in 2.1.22 and 2.1.65.
        html = editor._pastePreFilter(html=html, internal=False)
    else:
        html = internal_images_to_file(editor, html)
        html = download_external_images(editor, html)

    editor.note.fields[editor.myfield] = html
    editor.edited_field_content = ""
    if not editor.addMode:
        editor.note.flush()
    editor.loadNote(focusTo=editor.myfield)


def on_dialog_finished(editor, status):
    if status:
        editor.saveNow(lambda e=editor: editor_update_field(e))


def get_settings(chosen_name):
    if chosen_name in ["T6", "TM"]:
        defau1 = ("undo redo fontfamily blocks alignleft aligncenter alignright alignjustify "
                  "link unlink charmap cleanup nextCloze sameCloze code codesample")
        tb1 = gc("TinyMCE6-toolbar1", defau1)
        defau2 = ("bold italic underline strikethrough superscript subscript forecolor backcolor "
                  "removeformat hr blockquote numlist bullist anchor outdent indent table ltr rtl")
        tb2 = gc("TinyMCE6-toolbar2", defau2)
        return {
            "js_file": "tinymce6/js/tinymce/tinymce.min.js",
            "jssavecmd": "tinyMCE.activeEditor.getContent();",
            "wintitle": "Anki - edit current field in TinyMCE",
            "dialogname": "tinymce6",
            "webpath": f"/_addons/{addonfoldername}/web/",
            "body_except_for_field_content": readfile(
                addon_path, "template_tiny6_body.html"
            )
            % {
                "FONTSIZE": gc("fontSize"),
                "FONTNAME": gc("font"),
                #  https://www.tiny.cloud/blog/dark-mode-tinymce-rich-text-editor/
                "CUSTOMBGCOLOR": ""
                        if theme_manager.night_mode
                        else "this.getDoc().body.style.backgroundColor = '#e4e2e0';",
                # https://www.tiny.cloud/blog/dark-mode-tinymce-rich-text-editor/
                "CONTENTCSS": '"dark",' if theme_manager.night_mode else "",
                "DIRECTIONALITY": "ltr" if gc("left-to-right_by_default", True) else "rtl",
                "SKIN": "oxide-dark" if theme_manager.night_mode else "oxide",
                "THEME": "silver",
                "TOOLBAR1": tb1,
                "TOOLBAR2": tb2,
                "HILITERS": hiliters_tinymce
                        if gc("show background color buttons")
                        else "",
                "SCUT-Superscript": gc("dialog shortcut: superscript", "Ctrl+107"),
                "SCUT-Subscript": gc("dialog shortcut: subscript", "Ctrl+187"),
                "SCUT-RemoveFormat": gc("dialog shortcut: removeFormat", "Ctrl+r"),
                "SCUT-CodeEditor": gc("dialog shortcut: codeEditor", "Ctrl+Shift+X"),
                "SCUT-indent": gc("dialog shortcut: indent", "Ctrl+M"),
                "SCUT-outdent": gc("dialog shortcut: outdent", "Ctrl+Alt+M"),
                "SCUT-nextCloze": gc("dialog shortcut: nextCloze", "F7"),
                "SCUT-addCloze": gc("dialog shortcut: addCloze", "F8"),
                "SCUT-InsertUnorderedList": gc("dialog shortcut: insertUnorderedList", "F9"),
                "SCUT-InsertOrderedList": gc("dialog shortcut: insertOrderedList", "F10"),
                "SCUT-upperCase": gc("dialog shortcut: upperCase", "Ctrl+Alt+U"),
                "SCUT-lowerCase": gc("dialog shortcut: lowerCase", "Ctrl+Alt+L"),
                "SCUT-SpecialCharacter": gc("dialog shortcut: special character", "Ctrl+E"),
            },
        }
    for js_editor_name, settings_dict in additional_editors_dict.items():
        if chosen_name == js_editor_name:
            return settings_dict


def show_wysiwyg_dialog(editor, field, editorname):
    field_content = editor.note.fields[field]

    content_surrounded_with_div = False
    if field_content.startswith("<div>") and field_content.endswith("</div>"):
        content_surrounded_with_div = True

    settings = get_settings(editorname)
    html = maybe_pre_process_html(field_content)
    bodyhtml = settings["body_except_for_field_content"].replace("CONTENTCONTENT", html)
    dialog = ExtraWysiwygEditorForField(
        editor=editor,
        bodyhtml=bodyhtml,
        js_file=settings["js_file"],
        js_save_command=settings["jssavecmd"],
        wintitle=settings["wintitle"],
        dialogname=settings["dialogname"],
        content_surrounded_with_div=content_surrounded_with_div,
        web_path=settings["webpath"],
    )
    # exec_() doesn't work, see  https://stackoverflow.com/questions/39638749/
    dialog.finished.connect(
        lambda status, func=on_dialog_finished, e=editor: func(e, status)
    )
    dialog.setModal(True)
    dialog.show()
    dialog.web.setFocus()


def external_editor_start(editor, editorname):
    if editor.currentField is None:
        tooltip("no field focussed. Aborting ...")
        return
    editor.myfield = editor.currentField
    editor.saveNow(
        lambda e=editor, f=editor.myfield, n=editorname: show_wysiwyg_dialog(e, f, n)
    )


def keystr(k):
    key = QKeySequence(k)
    return key.toString(QKeySequence.SequenceFormat.NativeText)


def setupEditorButtonsFilter(buttons, editor):
    cut_T6 = gc("TinyMCE6 - shortcut to open dialog")
    tip_T6 = "edit current field in external window"
    if cut_T6:
        tip_T6 += " ({})".format(keystr(cut_T6))

    use_default = True if not gc("_TinyMCE6 - enable") else False
    cut_default = gc("shortcut to open default dialog")
    tip_default = f"edit current field in external window ({keystr(cut_default)})"

    arglist = [
        #  0                        1           2             3          4       5
        # show                    shortcut     tooltip     functionarg  cmd   icon
        [gc("_TinyMCE6 - enable"), cut_T6,      tip_T6,     "T6",       "T6", None],
        [use_default,             cut_default, tip_default, "TM",       "TM", None],
    ]
    additional_arglist = get_additional_arglist()
    arglist.extend(additional_arglist)
    for line in arglist:
        if not line[0]:
            continue
        b = editor.addButton(
            icon=line[5],  # os.path.join(addon_path, "icons", "tm.png"),
            cmd=line[4],
            func=lambda e=editor, n=line[3]: external_editor_start(e, n),
            tip=line[2],
            keys=keystr(line[1]) if line[1] else "",
        )
        buttons.append(b)

    return buttons
addHook("setupEditorButtons", setupEditorButtonsFilter)
