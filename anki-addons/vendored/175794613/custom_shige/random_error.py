
import random
from aqt.utils import tooltip

def custom_error(error_text=""):
    messages = [
        "Leaderboard : Can't connect to server, try again later :-/",
        "Leaderboard : Server timeout, try again later :-| ",
        "Leaderboard : Unable to connect to server, try again later :-O",
        "Leaderboard : Server not responding, try again later :-(",
        "Leaderboard : Connection failed, try again later :-/"
    ]
    message = random.choice(messages)
    time = 5000
    br = ""
    if error_text:
        messages = "Connection failed, try again later :-/"
        br = "<br>"
        time = 7000
    tooltip(f"{message}{br}{error_text}", time)