from aqt import QComboBox, QCompleter, Qt

class SearchableComboBox(QComboBox):
    def __init__(self, parent=None):
        super(SearchableComboBox, self).__init__(parent)
        self.setEditable(True)
        self.setInsertPolicy(QComboBox.InsertPolicy.NoInsert)
        # self.completer().setCompletionMode(QCompleter.CompletionMode.PopupCompletion)

        completer = self.completer()
        completer.setCompletionMode(QCompleter.CompletionMode.PopupCompletion)
        completer.setFilterMode(Qt.MatchFlag.MatchContains)