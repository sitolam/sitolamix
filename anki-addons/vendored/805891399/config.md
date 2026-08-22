### Warnings

As stated in the add-on description this add-on is just about bundeling an alternative WYSIWYG editor for the current field of an Anki note. The external editor used is TinyMCE version 6. **This external editor sometimes automatically modifies the field content which in some cases alters the appearance of your cards. This is expected behavior because this add-on is mostly about bundling tinymce with the default settings.**

**<span style="text-decoration:underline">A note about security</span>: I only use this add-on to modify field content that is already in Anki and to add content from trusted pdf files. The addon is not designed for other use cases. E.g. I do not copy content from websites or other untrusted sources directly into this addon window. When working with content from those sources I close my addon window and copy the content in the anki editor in the Add or Browser window.**

### Configuration

- `"font"`: (default: `"Times New Roman"`) and `"fontSize"` (default: `"20"`): The font and font size used in the extra dialog.
- `"left-to-right_by_default"`: For right-to-left languages writing systems set this to `false`.
- `"shortcut to open default dialog"` (default `"Ctrl+0"`): Hotkey to open the dialog
- `use Anki's built-in html processing` (default is `true`). For details see [here](https://forums.ankiweb.net/t/extended-editor-for-field-for-tables-search-replace-official-thread/552/98).
- `"TinyMCE6-toolbar1"`, `"TinyMCE6-toolbar2"`: These two options allow you to configure the toolbar buttons shown in the dialog. For details see the docs for TinyMCE6, e.g. https://www.tiny.cloud/docs/tinymce/6/available-toolbar-buttons/
- when configuring custom shortcuts for the editor with `"dialog shortcut: ... ` you might have to rely on javascript key codes.

<br/><br/><br/><br/><br/>
### problems, bugs
**If you have problems with this add-on**:<br/>1. Read [this Anki FAQ](https://faqs.ankiweb.net/when-problems-occur.html)<br/>2. Disable all other add-ons, then restart Anki and then try again. If this solves your problem you have an add-on conflict and must decide which add-on is more important for you. <br/>3. If you still have problems, reset the config of this add-on and restart Anki and try again. <br/>4. If it still doesn't work you can report the problem at https://forums.ankiweb.net/t/extended-editor-for-field-for-tables-search-replace-official-thread/552



<br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/>
This add-ons was made by ijgnd using some code from Anki and Hyun Woo Park.

This add-on bundles "TinyMCE6" in the addon subfolder web/tinymce6<br>
Copyright (c) 2022 Ephox Corporation DBA Tiny Technologies, Inc.<br>
"TinyMCE6" is licensed as MIT License. The license is in the add-on subfolder web/tinymce6/js/tinymce/license.txt

This add-on bundles the file "sync_execJavaScript.py" which has this copyright and permission notice:<br>
Original work Copyright (c): 2014 - 2016 Detlev Offenbach<br>
Modified work Copyright (c): 2021- ijgnd

This addon bundles parts of the htmlmin package, https://github.com/mankyd/htmlmin

This add-on bundles "jquery-3.5.1.min.js" 
