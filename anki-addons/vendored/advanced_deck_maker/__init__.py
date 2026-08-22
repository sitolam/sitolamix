from aqt import mw
from aqt.qt import QAction, QDialog, QKeySequence
from aqt.utils import showWarning, tooltip


def _current_deck_prefix() -> str:
    try:
        did = mw.col.decks.selected()
        name = mw.col.decks.name(did)
        return "" if name == "Default" else name + "::"
    except Exception:
        return ""


def _create_decks() -> None:
    from .dialog import AdvancedDeckDialog

    if not mw.col:
        showWarning("No collection open.")
        return

    dlg = AdvancedDeckDialog(mw, initial_text=_current_deck_prefix())
    if dlg.exec() != QDialog.DialogCode.Accepted:
        return

    names = [
        n.strip()
        for n in dlg.deck_names()
        if n.strip() and not n.strip().endswith("::")
    ]
    if not names:
        showWarning("No deck names to create.")
        return

    for name in names:
        mw.col.decks.id(name)

    mw.col.save()
    mw.reset()
    tooltip(f"Created {len(names)} deck(s).", period=2500)


# Replace the "Create Deck" button handler (method name changed across Anki versions)
try:
    from aqt.deckbrowser import DeckBrowser

    if hasattr(DeckBrowser, "_on_create"):
        DeckBrowser._on_create = lambda self: _create_decks()
    elif hasattr(DeckBrowser, "_add"):
        DeckBrowser._add = lambda self: _create_decks()
except Exception:
    pass

# Menu item / keyboard shortcut
_action = QAction("Advanced Deck Creator…", mw)
_action.setShortcut(QKeySequence("Ctrl+Shift+D"))
_action.triggered.connect(_create_decks)
mw.form.menuTools.addAction(_action)
