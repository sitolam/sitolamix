from aqt.qt import (
    QDialog,
    QDialogButtonBox,
    QKeyEvent,
    QLabel,
    QListWidget,
    QPlainTextEdit,
    QTextCursor,
    QVBoxLayout,
    Qt,
)

from .deck_parser import expand_deck_names

_HELP = (
    "<b>Syntax</b><br>"
    "&nbsp;&nbsp;<code>Parent::Child1||Child2</code> &mdash; sibling decks<br>"
    "&nbsp;&nbsp;<code>Parent::{A,B,C}</code> &mdash; brace expansion<br>"
    "&nbsp;&nbsp;One expression per line &mdash; <b>Enter</b> creates, <b>Shift+Enter</b> new line"
)


class _DeckEdit(QPlainTextEdit):
    def __init__(self, dialog: "AdvancedDeckDialog"):
        super().__init__()
        self._dialog = dialog

    def keyPressEvent(self, e: QKeyEvent) -> None:
        if e.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
            if e.modifiers() & Qt.KeyboardModifier.ShiftModifier:
                super().keyPressEvent(e)
            else:
                self._dialog.accept()
        else:
            super().keyPressEvent(e)


class AdvancedDeckDialog(QDialog):
    def __init__(self, parent=None, initial_text: str = ""):
        super().__init__(parent)
        self.setWindowTitle("Advanced Deck Creator")
        self.setMinimumWidth(520)
        self._setup_ui(initial_text)

    def _setup_ui(self, initial_text: str) -> None:
        layout = QVBoxLayout(self)

        help_label = QLabel(_HELP)
        help_label.setTextFormat(Qt.TextFormat.RichText)
        layout.addWidget(help_label)

        self.text_edit = _DeckEdit(self)
        self.text_edit.setPlaceholderText(
            "6e jaar::2e deel::Engels::Test1||Test2\n"
            "Bio::{Hoofdstuk 1,Hoofdstuk 2}"
        )
        self.text_edit.setMinimumHeight(110)
        if initial_text:
            self.text_edit.setPlainText(initial_text)
            cursor = self.text_edit.textCursor()
            cursor.movePosition(QTextCursor.MoveOperation.End)
            self.text_edit.setTextCursor(cursor)
        layout.addWidget(self.text_edit)

        layout.addWidget(QLabel("Preview:"))
        self.preview = QListWidget()
        self.preview.setMaximumHeight(150)
        layout.addWidget(self.preview)

        btns = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok
            | QDialogButtonBox.StandardButton.Cancel
        )
        btns.accepted.connect(self.accept)
        btns.rejected.connect(self.reject)
        layout.addWidget(btns)

        self.text_edit.textChanged.connect(self._refresh_preview)

    def _refresh_preview(self) -> None:
        self.preview.clear()
        text = self.text_edit.toPlainText().strip()
        if not text:
            return
        try:
            for name in expand_deck_names(text):
                self.preview.addItem(name)
        except Exception:
            pass

    def deck_names(self):
        return expand_deck_names(self.text_edit.toPlainText())
