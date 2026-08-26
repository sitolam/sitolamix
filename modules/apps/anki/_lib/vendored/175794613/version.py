# Anki Leaderboard
# Copyright (C) 2020 - 2024 Thore Tyborski <https://github.com/ThoreBor>
# Copyright (C) 2024 Shigeyuki <http://patreon.com/Shigeyuki>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

from os.path import dirname, join

from .shige_pop.popup_config import SPECIAL_THANKS, PATRONS_LIST, OLD_CHANGE_LOG, NEW_FEATURE
from .custom_shige.translate.translate import ShigeTranslator
# from .custom_shige.path_manager import HOW_TO_USE_TR as how
from .path_manager import ADDON_NAME

# version = "v4.0 (Fixed by Shige)"
version = "v5.0 (Fixed by Shige)"

special_thanks = SPECIAL_THANKS.replace('[ Patreon ]', '<b>[ Patreon ]</b>').replace('\n', '<br>')

new_feature = NEW_FEATURE.replace('\n', '<br>')
old_change_log = OLD_CHANGE_LOG.replace('\n', '<br>')

_tr = ShigeTranslator.translate


addon_path = dirname(__file__)
rate_this_path = join(addon_path, "rate_this_addon.jpg")
# rate_this_path = r"C:\Users\shigg\AppData\Roaming\Anki2\addons21\Anki Leaderboard (Fixed by Shige)\rate_this_addon.jpg"


# plus
patron_url_href = '<a href="https://www.patreon.com/posts/154968535" target="_blank">'
try:
    _Leaderboar_plus_path = join(dirname(__file__), "Leaderboard_plus.webp")
    str_Leaderboar_plus_path = (
        f'{patron_url_href}'
        f'<img src="{_Leaderboar_plus_path}"></a>'
    )
except Exception as e:
    print(f"[{ADDON_NAME}] ")
    str_Leaderboar_plus_path = ""




about_text = f"""
<h2>🏅Anki Leaderboard {version}</h2>

AnkiWeb URL : <a href="https://ankiweb.net/shared/info/175794613">https://ankiweb.net/shared/info/175794613</a><br>
add-on code : <code>175794613</code><br>

<br>
<b>📖How to use :</b><br>

See Wiki for how to use it.<br>
<a href="https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html"><b>Anki Leaderboard Wiki</b></a><br>

<br>
<b>🔗Related Add-ons (Created by Shige) : </b><br>
&nbsp;&nbsp;&nbsp;&nbsp;[1]&nbsp;<a href="https://ankiweb.net/shared/info/978245457">📱Discord RP for Anki Leaderboard- study activity status </a><br>
&nbsp;&nbsp;&nbsp;&nbsp;[2]&nbsp;<a href="https://ankiweb.net/shared/info/1797615099">📌Rearrange home addons </a><br>
&nbsp;&nbsp;&nbsp;&nbsp;[3]&nbsp;<a href="https://ankiweb.net/shared/info/906950015">🐻TidyAnkiBear - Select and hide Anki menu bar items</a><br>

<br>
[ 🎮Shige's Gamification add-ons ] Hi thanks for using this add-on I'm Shige!😆 I develop as a hobby and so far I've fixed 80+ broken add-ons for free by request from users and released 30+ original add-ons for free! If you become a patron ($5/month) and support my volunteer development you can download the Patrons only add-on Anki Leaderboard Plus.<br>
{str_Leaderboar_plus_path}<br>
[ {patron_url_href}🏆️Anki Leaderboard Plus (Patrons only)</a> ] Leaderboard displayed on top bar and updated in real time during review! This version added sync speed optimization and enhancements, UI for gamification mode, toast notifications for scores, improved tooltip design, and enhanced options, etc. Revenue from this add-on will be used to maintain and enhance the leaderboard Free server. (Not related to the official Anki.)<br>

<br>
<b>👍️Please Rate this : </b><br>
If you like this add-on please rate it on the add-on page!
<br>
<a href="https://ankiweb.net/shared/review/175794613">
<img src="{rate_this_path}" alt="rate this addon"><br>
</a><br>

<b>Share : </b> Let's invite your friends and study with Anki together! <br>
<style>
    .share-button {{
        color: white;
        text-align: center;
    }}
    .twitter {{
        background-color: #1DA1F2;
    }}
    .reddit {{
        background-color: #FF4500;
    }}
    .facebook {{
        background-color: #3b5998;
    }}
</style>
<a href="https://twitter.com/intent/tweet?url=https://ankiweb.net/shared/info/175794613&text=Let's study with Anki Leaderboard" target="_blank" class="share-button twitter">&nbsp; Share on X &nbsp;</a> &nbsp;
<a href="https://www.reddit.com/submit?url=https://ankiweb.net/shared/info/175794613&title=Let's study with Anki Leaderboard" target="_blank" class="share-button reddit">&nbsp; Share on Reddit &nbsp;</a> &nbsp;
<a href="https://www.facebook.com/sharer/sharer.php?u=https://ankiweb.net/shared/info/175794613" target="_blank" class="share-button facebook">&nbsp; Share on Facebook &nbsp;</a>
<br>

<hr>

<b>Change log:</b><br>
{new_feature}<br>
{old_change_log}<br>

<br>
<hr>
{special_thanks}<br><br>
{PATRONS_LIST}<br><br>


<hr>
<b>Credit (Images) :</b>
<div>Crown icon made by <a href="https://www.flaticon.com/de/autoren/freepik" title="Freepik">Freepik</a> from <a href="https://www.flaticon.com/de/" title="Flaticon">www.flaticon.com</a></div>
<div>Person icon made by <a href="https://www.flaticon.com/de/autoren/iconixar" title="iconixar">iconixar</a> from <a href="https://www.flaticon.com/de/" title="Flaticon">www.flaticon.com</a></div>
<div>Settings icon made by <a href="https://www.flaticon.com/free-icons/setting" title="setting icons">Setting icons created by Phoenix Group - Flaticon</a>
<div>Confetti gif from <a href="https://giphy.com/stickers/giphycam-rainbow-WNJATm9pwnjpjI1i0g">Giphy</a></div>
<div>Rank icon : Rhos @RhosGFX <a href="https://x.com/rhosgfx">https://x.com/rhosgfx</a></div>
<div>Star icon : Clip Art Library <a href="https://commons.wikimedia.org/wiki/File:Star_icon_stylized.svg">https://commons.wikimedia.org/wiki/File:Star_icon_stylized.svg</a></div>
<div>ProgressBars : <a href="https://bdragon1727.itch.io/">BDragon1727</a></div>
<div>TimeRank : <a href="https://warstellar.itch.io/fictional-military-ranks-icons-set">Warstellar Interactive</a></div>
<div>Tree : <a href="http://yms.main.jp">Pixel Art World</a></div>
<div>Orb and Crystal : Nanamiyuki atelier</div>
<div>WeatherIcons : illust-AC</div>

<br>
<hr>
<b>Copyright:</b><br>
This Add-on is a customized version (Fork) of LeaderBoard.<br>
The original LeaderBoard was created by Thore Tyborski.<br>
<a href="https://github.com/ThoreBor">(c) Thore Tyborski 2020 - 2024</a><br>
<a href="http://patreon.com/Shigeyuki">(c) Shigeyuki 2024</a>
<b>Contributions :</b>
<a href="https://github.com/khonkhortisan"> khonkhortisan</a>,
<a href="https://github.com/zjosua">zjosua</a>,
<a href="https://www.reddit.com/user/SmallFluffyIPA/">SmallFluffyIPA</a>,
<a href="https://github.com/AtilioA">Atílio Antônio Dadalto</a>,
<a href="https://github.com/rodrigolanes">Rodrigo Lanes</a>,
<a href="https://github.com/abdnh">Abdo</a>

"""

# &nbsp;&nbsp;&nbsp;&nbsp;[3]&nbsp;<a href="https://ankiweb.net/shared/info/33855257">📱Anki Discord Sidebar - Chat room within Anki</a><br>



# about_text = f"""
# <h2>🏅Anki Leaderboard {version}</h2>

# AnkiWeb URL : <a href="https://ankiweb.net/shared/info/175794613">https://ankiweb.net/shared/info/175794613</a><br>
# add-on code : <code>175794613</code><br>

# <br>
# <b>📖{_tr(how, "How to use")} :</b><br>
# {_tr(how, "This add-on ranks all of its users by the number of cards reviewed today, time spend studying today, current streak, reviews in the past 31 days, and retention.")}<br>
# {_tr(how, "You can also compete against friends, join groups, and join a country leaderboard.")}<br>
# {_tr(how, "You'll only see users, that synced on the same day as you.")}<br>
# <br>
# <b>🏆{_tr(how, "League")} :</b><br>
# {_tr(how, "In the league tab, you see everyone who synced at least once during the current season. There are four leagues (Alpha, Beta, Gamma, and Delta).")}<br>
# The top 20% will be promoted, and the bottom 20% will be demoted.<br>
# Start -> Delta -> Gamma -> Beta -> Alpha <br>
# <br>
# <b>📅{_tr(how, "Season")} (League) :</b><br>
# {_tr(how, "A season lasts two weeks. You don't have to sync every day.")}<br>
# For now I have it set to tally after 3 days and start a new league on the next Monday. (Because of time zone differences between countries and the time it takes mobile users to sync leagues on their PC)<br>
# <br>

# <b>👥{_tr(how, "Group")} : </b><br>
# &nbsp;&nbsp;&nbsp;&nbsp;[1] {_tr(how, "By default, there are public groups for Medicine, Language, and Pokemon.(pass 1234)")}<br>
# &nbsp;&nbsp;&nbsp;&nbsp;[2] {_tr(how, "If you want to delete the group, please contact me.")}<br>
# &nbsp;&nbsp;&nbsp;&nbsp;[3] If you do not set a password, an error will occur. If anyone can enter, please include the pass in your group name.<br>
# <br>
# <b>📈<a href="https://github.com/ThoreBor/Anki_Leaderboard/issues/122">{_tr(how, "XP formula")} :</b><a/><br>
# <code>{_tr(how, "XP = days studied percentage x ((6 x time) + (2 x reviews x retention))")}</code><br>
# {_tr(how, "You have to study at least 5 minutes per day. Otherwise, this day won't be counted as “studied” (See this issue for more info).")}<br>
# {_tr(how, "At the end of each season, the top 20% will be promoted, and the last 20% will be relegated.")}<br>
# <br>
# <b>🌐<a href="https://shigeyuki.pythonanywhere.com/">{_tr(how, "Website")} : </b></a><br>
# {_tr(how, "You can check the leaderboard (past 24 hours) on this website.")}<br>
# <br>
# <b>🔗{_tr(how, "Related Add-ons (Created by Shige)")} : </b><br>
# &nbsp;&nbsp;&nbsp;&nbsp;[1]&nbsp;<a href="https://ankiweb.net/shared/info/1797615099">📌Rearrange home addons </a><br>
# &nbsp;&nbsp;&nbsp;&nbsp;[2]&nbsp;<a href="https://ankiweb.net/shared/info/906950015">🐻TidyAnkiBear - Select and hide Anki menu bar items</a><br>
# &nbsp;&nbsp;&nbsp;&nbsp;[3]&nbsp;<a href="https://ankiweb.net/shared/info/33855257">📱Anki Discord Sidebar - Chat room within Anki</a><br>
# <br>
# <br>
# <b>👍️Please Rate this : </b><br>
# Hello thank you for using this add-on, I'm Shige!😆 The leaderboard is a special add-on that uses the server, unless I manage it regularly it will be broken in a few months, so If you like this add-on please support my volunteer development by rating, sharing, and donating. Thank you! <br>
# <br>
# <a href="https://ankiweb.net/shared/review/175794613">
# <img src="{rate_this_path}" alt="rate this addon"><br>
# </a><br>

# <b>Share : </b> Let's invite your friends and study with Anki together! <br>
# <style>
#     .share-button {{
#         color: white;
#         text-align: center;
#     }}
#     .twitter {{
#         background-color: #1DA1F2;
#     }}
#     .reddit {{
#         background-color: #FF4500;
#     }}
#     .facebook {{
#         background-color: #3b5998;
#     }}
# </style>
# <a href="https://twitter.com/intent/tweet?url=https://ankiweb.net/shared/info/175794613&text=Let's study with Anki Leaderboard" target="_blank" class="share-button twitter">&nbsp; Share on X &nbsp;</a> &nbsp;
# <a href="https://www.reddit.com/submit?url=https://ankiweb.net/shared/info/175794613&title=Let's study with Anki Leaderboard" target="_blank" class="share-button reddit">&nbsp; Share on Reddit &nbsp;</a> &nbsp;
# <a href="https://www.facebook.com/sharer/sharer.php?u=https://ankiweb.net/shared/info/175794613" target="_blank" class="share-button facebook">&nbsp; Share on Facebook &nbsp;</a>
# <br>

# <hr>
# <b>Copyright:</b><br>
# This Add-on is a customized version (Fork) of LeaderBoard.<br>
# The original LeaderBoard was created by Thore Tyborski.<br>
# <a href="https://github.com/ThoreBor">(c) Thore Tyborski 2020 - 2024</a><br>
# <a href="http://patreon.com/Shigeyuki">(c) Shigeyuki 2024</a>
# <hr>
# <b>Contributions :</b>
# <a href="https://github.com/khonkhortisan"> khonkhortisan</a>,
# <a href="https://github.com/zjosua">zjosua</a>,
# <a href="https://www.reddit.com/user/SmallFluffyIPA/">SmallFluffyIPA</a>,
# <a href="https://github.com/AtilioA">Atílio Antônio Dadalto</a>,
# <a href="https://github.com/rodrigolanes">Rodrigo Lanes</a>,
# <a href="https://github.com/abdnh">Abdo</a>
# <hr>
# <b>Credit (Images) :</b>
# <div>Crown icon made by <a href="https://www.flaticon.com/de/autoren/freepik" title="Freepik">Freepik</a> from <a href="https://www.flaticon.com/de/" title="Flaticon">www.flaticon.com</a></div>
# <div>Person icon made by <a href="https://www.flaticon.com/de/autoren/iconixar" title="iconixar">iconixar</a> from <a href="https://www.flaticon.com/de/" title="Flaticon">www.flaticon.com</a></div>
# <div>Settings icon made by <a href="https://www.flaticon.com/free-icons/setting" title="setting icons">Setting icons created by Phoenix Group - Flaticon</a>
# <div>Confetti gif from <a href="https://giphy.com/stickers/giphycam-rainbow-WNJATm9pwnjpjI1i0g">Giphy</a></div>
# <hr>
# {special_thanks}<br><br>
# {PATRONS_LIST}
# """

# # 使ってない
# _about_text = f"""
# <h2>🏅Anki Leaderboard {version}</h2>
# <b>📖How to use :</b><br>
# This add-on ranks all of its users by the number of cards reviewed today, time spend studying today,
# current streak, reviews in the past 31 days, and retention.<br>
# You can also compete against friends, join groups, and join a country leaderboard.<br>
# You'll only see users, that synced on the same day as you.<br>
# <br>
# <b>🏆League :</b><br>
# In the league tab, you see everyone who synced at least once during the current season. There are four leagues
# (Alpha, Beta, Gamma, and Delta).<br>
# <br>
# <b>📅Season :</b><br>
# A season lasts two weeks. You don't have to sync every day.<br>
# <br>

# <b>👥Group : </b><br>
# &nbsp;&nbsp;&nbsp;&nbsp;[1] By default, there are public groups for Medicine, Language, and Pokemon.(pass 1234)<br>
# &nbsp;&nbsp;&nbsp;&nbsp;[2] If you want to delete the group, please contact me.<br>
# <br>
# <b>📈XP formula :</b><br>
# <code>XP = days studied percentage x ((6 x time) + (2 x reviews x retention)) </code><br>
# You have to study at least 5 minutes per day. Otherwise, this day won't be counted as “studied”
# (<i><a href="https://github.com/ThoreBor/Anki_Leaderboard/issues/122">See this issue for more info<a/></i>).
# At the end of each season, the top 20% will be promoted, and the last 20% will be relegated.<br>
# <br>
# <b>🌐Website : </b><br>
# You can check the leaderboard (past 24 hours) on this website.<br>
# <br>
# <b>🔗Related Add-ons (Created by Shige) : </b><br>
# &nbsp;&nbsp;&nbsp;&nbsp;[1]&nbsp;<a href="https://ankiweb.net/shared/info/33855257">📱Anki Discord Sidebar - Chat room within Anki</a><br>
# &nbsp;&nbsp;&nbsp;&nbsp;[2]&nbsp;<a href="https://ankiweb.net/shared/info/906950015">🐻TidyAnkiBear - Select and hide Anki menu bar items</a><br>
# &nbsp;&nbsp;&nbsp;&nbsp;[2]&nbsp;<a href="https://ankiweb.net/shared/info/174058935">🍿Anki pop up - After 10 cards, take a 3 minute break</a><br>

# <hr>
# <b>Copyright:</b><br>
# This Add-on is a customized version (Fork) of LeaderBoard.<br>
# The original LeaderBoard was created by Thore Tyborski.<br>
# <a href="https://github.com/ThoreBor">(c) Thore Tyborski 2020 - 2024</a><br>
# <a href="http://patreon.com/Shigeyuki">(c) Shigeyuki 2024</a>
# <hr>
# <b>Contributions :</b>
# <a href="https://github.com/khonkhortisan"> khonkhortisan</a>,
# <a href="https://github.com/zjosua">zjosua</a>,
# <a href="https://www.reddit.com/user/SmallFluffyIPA/">SmallFluffyIPA</a>,
# <a href="https://github.com/AtilioA">Atílio Antônio Dadalto</a>,
# <a href="https://github.com/rodrigolanes">Rodrigo Lanes</a>,
# <a href="https://github.com/abdnh">Abdo</a>
# <hr>
# <b>Credit (Images) :</b>
# <div>Crown icon made by <a href="https://www.flaticon.com/de/autoren/freepik" title="Freepik">Freepik</a> from <a href="https://www.flaticon.com/de/" title="Flaticon">www.flaticon.com</a></div>
# <div>Person icon made by <a href="https://www.flaticon.com/de/autoren/iconixar" title="iconixar">iconixar</a> from <a href="https://www.flaticon.com/de/" title="Flaticon">www.flaticon.com</a></div>
# <div>Settings icon made by <a href="https://www.flaticon.com/free-icons/setting" title="setting icons">Setting icons created by Phoenix Group - Flaticon</a>
# <div>Confetti gif from <a href="https://giphy.com/stickers/giphycam-rainbow-WNJATm9pwnjpjI1i0g">Giphy</a></div>
# <hr>
# {special_thanks}<br><br>
# {PATRONS_LIST}
# """