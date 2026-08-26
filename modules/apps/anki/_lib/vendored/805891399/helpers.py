import os
import re

from aqt.utils import tooltip

from .config import gc
from .htmlmin import minify


addon_path = os.path.dirname(__file__)
addonfoldername = os.path.basename(addon_path)
user_files_folder = os.path.join(addon_path, "user_files")


hiliters_tinymce = """
    // TODO change to class applier
    hilite(editor, tinymce, 'hiliteGreen',"#00ff00",'alt+w','GR');
    hilite(editor, tinymce, 'hiliteBlue',"#00ffff",'alt+e','BL');
    hilite(editor, tinymce, 'hiliteRed',"#fd9796",'alt+r','RE');
    hilite(editor, tinymce, 'hiliteYellow',"#ffff00",'alt+q','YE');
"""   


def readfile(folder, file):
    filefullpath = os.path.join(folder, file)
    with open(filefullpath, 'r', encoding='utf-8') as f:
        return f.read()


def maybe_pre_process_html(html):
    # tinymce adds nbsp; into empty divs which causes a visual new line for me.
    # https://stackoverflow.com/questions/42533795/how-to-prevent-tinymce-from-inserting-nbsp-into-empty-elements-without-changin
    # > you can trick TinyMCE into thinking that an element isn't empty, by inserting
    #   a html comment inside it.
    html = html.replace("<div></div>", "<div><!--1043915942--></div>")
    html = html.replace("<div> </div>", "<div> <!--1043915942--></div>")
    return html


def post_process_html(html, surrounded):
    to_remove = [
        "<!--StartFragment-->",
        "<!--EndFragment-->",
    ]
    if not isinstance(html, str):
        tooltip("error in addon")
        return ""
    for l in to_remove:
        html = html.replace(l, "")

    # workaround tinymce wrapping content, see https://github.com/tinymce/tinymce/issues/7297
    if not surrounded and html.startswith("<div>") and html.endswith("</div>"):
        # .*? should be non-greedy, see
        # https://docs.python.org/3/howto/regex.html#greedy-versus-non-greedy
        html = re.sub(r"^<div>(.*?)</div>", r"\1", html, count=1)
        if html.endswith("</div>"):
            html = re.sub(r"<div>(.*?)</div>$", r"\1", html, count=1)

    if not gc("format code after closing (minify/compact)", True):
       return html
    html = html.replace("<div><!--1043915942--></div>", "<div></div>")
    html = html.replace("<div> <!--1043915942--></div>", "<div> </div>")
    # https://htmlmin.readthedocs.io/en/latest/reference.html
    html = minify(html, remove_empty_space=True, keep_pre=True)
    return html
