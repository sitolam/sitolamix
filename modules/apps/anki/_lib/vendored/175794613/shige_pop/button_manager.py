from aqt import QPushButton, QSizePolicy, Qt

def mini_button(button:QPushButton):
    button.setStyleSheet("QPushButton { padding: 2px; }")
    button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
    button.setFocusPolicy(Qt.FocusPolicy.NoFocus)


def mini_button_v2(button:QPushButton, is_blue=False):
    if is_blue:
        button.setStyleSheet("QPushButton { padding: 2px 10px; background-color: lightblue; color: black; }")
    else:
        button.setStyleSheet("QPushButton { padding: 2px 10px; }")
    button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
    button.setFocusPolicy(Qt.FocusPolicy.NoFocus)


def mini_button_v3(button:QPushButton):
    button.setStyleSheet("QPushButton { padding: 2px 8px; }")
    button.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed)
    button.setFocusPolicy(Qt.FocusPolicy.NoFocus)