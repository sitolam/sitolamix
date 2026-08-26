


OLD_CHANGE_LOG = """
---
2026-06-04: Minor Update
    - Added Discord buttons to Home.
    - Added active user count to Home.
---

2026-04-13
[ Enhanced ]
    - Added a feature to show/hide Home
    - Added a feature to hide the profile icon on Home.
    - Added a feature to hide game icons on Home.
    - Added symbols to the drop box.
    - Adjusted the UI.

2026-03-18
[ Bug fixed ]
    - Fixed a bug in the dropdown menu.
    - Enhanced the dropdown menu.
    - Removed tom-select as it is no longer needed.

2026-03-16
[ Enhanced Home leaderboard ]
    - Enhanced the sync button and icons.
    - Added a tooltip for the last sync time.
    - Added a download function for the Home icon.
    - Added tom-select for country icons.
        (tom-select, CDN, Apache License V2.0)
    - Added a Join button for countries.
    - Added a sort button.
    - Added a Change Board button.
    - Enhanced crash prevention measures.
    - Added a Change League button.
    - Added a Change Page button.
    - Added a group search button and window.
    - Adjusted the score text.
    - Enhanced features to avoid conflicts with other add-ons.
    - Add buttons to hide and show the Home leaderboard.
    - Enhanced support for the Onigiri and Beautify-Anki add-ons.
    - Enhanced the sign-up feature for new users.
    - Enhanced cache for wndow and home leaderboard.
    - Fixed the hidden user bug.
    - Fixed a bug with rank display.

[ Enhanced server ]
    - Optimized the send data and reduced its size by about 90%.
    - Limited user data acquisition to within one month.
    - Enhanced timeout handling.

[ Enhanced add-on ]
    - Added workaround for Config bug (beta).
    - Fixed Leaderboard button on Home.
    - Corrected typos.
    - Adjusted time display in the game mode.
    - Adjusted MINI button.
    - Adjusted SORT button.
    - Fixed time calculation bug.
    - Added Esc key support.
    - Added popup to Bio URL.
    - Added collapsible feature to Bio.


2026-01-13
- Enhanced server.
- Extended the sync timeout period (connection enhancement).
- Limited sync to once per minute (prevents repeated clicks).

2025-11-16
- Add code for Discord RP add-on (under development)

2025-11-06
[1] Enhancements (Discord)
I created a Discord server for the leaderboard.
You can access it via the invite link in the menu.
Leaderboard Menu -> Discord Invite URL
(https://discord.gg/XUrGSX9UME)

Also if using gamification mode, Discord channel buttons
will appear in the leaderboard window.
- Channels: Global, Some countries, leagues, some groups

If not needed you can optionally hide these buttons and the menu.
- Config -> Others -> Gamification mode -> Show Discord Button

2025-10-15
[1] Enhanced server
- Fixed a bug where password reset did not work

2025-05-30
- Reduced limits for time and review, etc.
- Fixed a bug that user info was not displayed when AlwaysOnTop was enabled.

2025-05-15
Added a function to call the leaderboard window from my add-on BreakTimer. (prototype)

2025-04-27
Fixed a bug that medals were not displayed.

2025-04-29
[1] Remove restrictions.(4-25 1sec -> 0.001sec)
    - After discussion, this restriction has been removed.
    - Only a workaround for batch processing will be added.
    - Version restrictions have been removed.
There are often requests for restrictions on cheaters, but so far there is no specific definition of cheaters, so if such restrictions are to be added we need a discussion in the AnkiForums thread before they are added.

2025-04-25
[1] Enhancements
    - added anti cheat measures.
        Reviews need at least 1 second and streaks need more than 0 seconds.
        Grade now was added in Anki25.05 so it is possible that more users will use this.
    - version update  v4.0 -> v5.0

2025-04-17
I added all the missing flags. (Svalbard & Jan Mayen, Ascension Island, Canary Islands, Ceuta & Melilla, St. Helena, Tristan da Cunha, Diego Garcia)

2025-04-15
Fixed bug for Qt5

2025-04-14
[1] Enhancements for more users
Gamification mode had a delay problem when the number of users increases. In the future Anki may freeze, so I developed a function to split pages and display them separately. Scrolling will automatically move the page. If gamification mode is off, this function is not available.

[2] Color change option
I received several requests to change the color of the page, so I developed an option. The color can be set separately for light mode and dark mode. Leaderboard config -> Others tab -> Graphics -> Color settings
The default color is now lighter. If you want to restore the previous color, you can do so in Settings. Color settings -> Others tab -> Restor Old Colors

2025-04-14
[ Additional explanation of gamification mode ]

- About the new leaderboard
In this update, the leaderboard has been almost completely redesigned to add page change functionality. (Gamification mode only.) These changes allow us to support more users. However there are a lot of internal code changes so it may be a bit bug prone. If you find any problems or missing features, please contact me.

- Safe Mode
The original leaderboard and the new leaderboard work with different code. So if the gamification mode leaderboard does not work for some reason, it is likely that you can use the original leaderboard by turning off the mode. (like safe mode)

[ bottom right of global leaderboard ]

- Mini mode:
Make the gamification mode display as small as possible. Press it once again to restore it.

- Change Sort Option:
Added an option to quickly change the sort of the leaderboard (Review, Time, 31days, Streaks, Retention.You need to restart the leaderboard for the changes to take effect.

[ bottom left of the global leaderboard ]
- Top button: Moves to the top of the leaderboard.
- You button: Moves to the position of your score.
- Arrows and combo box: navigate the page when selected.

[ Others ]
- The medals on the leaderboard are now displayed on the second line.
- Added a function to display grades (A+, A, B+, etc.)
- Enhanced option to hide RateThis button.
- Enhanced the function to change the zoom.
- Enhanced the function to change the font.
- Scrolling to user position is now more accurate.
- Added mouse animation during loading.

- The home leaderboard is still under development, so the icon is not shown.
- Wiki is not written yet.

---

2025-03-22
[1] The Syrian flag has been updated to the new flag.

2025-03-21
[1] Fix show rate and donation buttons option not working.

2025-03-18
[1] Added flags of Eurozone and CaribbeanNetherlands.

2025-03-09
[1] Small Bug Fixed for Linux (Python3.12+)

---
2025-03-03
[1] Server enhancements
So far the leaderboard is getting about 1000 new users every 1-2 months, so I've upgraded the server to make it about 70 times faster and more efficient. The database has been rebuilt and all data has been moved (Sqlite3->MySQL) This solved the problem of occasional new registrations and the delay problem.

[2] Bug fixes
Fixed a bug that groups are not displayed in web leaderboards.

[3] Enhancements
[ Gamification mode ]
Enhanced gamification with more icons and numerical feedback. If you don't like it, you can disable it at once in the options(Config -?> Oters tab). The code is not optimized yet, so there is a disadvantage for now that it increases the delay before the window is displayed.

[a] Display of yesterday's users:  Added a function to display the scores of users who logged in yesterday and not only today.
Users who logged in today will see a green dot. If you do not like this yesterday, you can optionally disable it (Show only today's users).
[b] Review progress bar: This will reach 100% when the average number of reviews for the month is reached.
[c] Timer Rank: The rank changes by the learning time. Maximum 12 hours.
[d] Streaks tree: A tree grows after one week and can grow up a maximum of 3 years.
[e] 31days orbs and crystals: Colorful orbs and crystals are displayed based on the average number of reviews in the last 31 days. The orb will change color and shape for every 100 reviews, counting in 10 steps until 3000 reviews. After that, the orb counts every 1000 reviews up to a maximum of 10000 reviews.
[f] Weather icon of retention rate: The weather icon changes according to the retention rate.
[g] XP level: Calculates and displays the level from the XP. The blue progress bar indicates the XP required for the next level.

[ Enhanced numerical display ]
[a] Review: Added a function to display seconds in review. The 0-2 seconds/card is indicated by a patlamp. (Since the most common reason reported so far is that the review is too fast.) This function is only for display, so there is no penalty for now. If you are reviewing too fast for some reason, I recommend you to write the reason in Bio. (Because Bio will be displayed when someone reports a user.)
[b] Streaks: The year, month and date are displayed. Added a function that sometimes display cracker or cake by streaks.

[ Other ]
1. Enhanced auto-align function for leaderboards.
2. Moved the league icon to the far left.
3. Added a function to keep the leaderboard window always on top.
4. Added function to show tooltips when resizing.
5. Added a function to display the total number of users in the column header.
6. Added a function to display rank (A+ ... F).
7. Added display of country name.
8. Added time and sun or moon icons to country leaderboard.
9. Added function to save window position.


2024-11-10
[ 🔥Enhanced ]
    [1] Zoom: Added + and - buttons to the global leaderboard. Press to zoom in and out on the leaderboard. The default setting is 1.5x.
    [2] Font: Added a gear button to the global leaderboard. Press to change the leaderboard font.
    [3] Resize: Auto saves and reproduces the leaderboard size.

📝If distracting, you can disable by config: Config -> Others tab -> Zoom and Font Enable

[4] Achievement: Enhanced Achievement for Streaks.

[ 🐞Bug Fixed ]
[1] Fixed to auto select leagues.


2024-10-27
[1] VS Countries
    1. Added a leaderboard for competing in countries (Past31day, Login within 7days).
    2. You can now see leaderboards of other countries.
    3. Since there are time differences yesterday's users will be shown in gray text.

[2] Search Users
    1. Added a search Users button for adding friends.
    If you are concerned about privacy, please do not add personal info.

These functions can be disable in the settings, if you find it distracting or new features cause bugs use this to disable it. (Config -> others tab -> Add picture of country, league and profile)

[3] Sync multiple devices
    1. Added workaround for problem with multiple devices.
        - Config data can be saved to AnkiWeb when syncing decks.
        - The saved data must be downloaded manually.
        - Config -> Others tab -> Sync multiple devices

[4] Home
    1. Added user and friend highlights to the leaderboard in Home.
    1. Fixed a bug that caused an error when there are too few users in Home.


2024-10-23
[1] 🚀Enhancements
    [1] Profile Icons (Prototype)
        - Added function to display profile icons on the leaderboard.
        - You can upload your pictures to the server from the new menu.
            (Menu - > Leaderboard -> Upload profile image)

    [2] Added function to hide user names on the Hidden Users tab in Config.

[2] 🐛Bug fixed
    [1] Fixed a bug that prevented sync at startup.
    [2] Optimized some functions.
    [3] Improved reloading process.


2024-10-16
[1] 🔥Enhancements
    [1] Country flags
        - Added country flag icons to all league tabs.
    [2] Rank icons
        - Added Rank icons to all league tabs.
    [3] Tooltip
        - Added function to display name, review data, etc.
        - Pop up tooltip when leaderboard is opened.
    [4] Extra Grade
        - Add ranks for star icons, and A+ to F.
    [5] Switch leagues
        - You can switch between Alpha, Beta, Gamma, and Delta leagues.

    📝Note : These functions can be disable in the settings.
        - Config -> others tab -> add Pic country and league

[2] 🐞Bug fixed
    - Fixed duplicate leaderboard window.
    - Fixed the leaderboard window to hidden when Anki refreshed.

2024-10-12
[1] 🔥Enhancements
    - Added function to display country flags in the global tab.
    - Added function to display the shield of each league in the global tab.
    - Optimized display of global tabs.
    - This function can be hidden in the settings.
        (Config -> others tab -> add pic country and league)
    - Icons for non-global tabs are still under development.
    - If you have not yet configured your country, you will become Pirate.

2024-10-09
[1] 🔥Enhancements
    - Enhanced function to hidden users in League and Home.
[2] 🐞Bug fixed
    - Fixed a bug in importing and exporting friends.

2024-08-30 ----
[1] Bug fixed
    - Fixed a bug that home does not show groups.
    - Fixed a bug that sometimes the Home button does not work.

[2] Enhancements
    - Enhanced option to sync after review.

2024-08-07 ----
[1] Added display of number of active users.

2024-07-08 ----
[1] Bug fixed
    Fixed a problem that caused division by zero errors for some users.
    If you continue to encounter problems, please contact me again.


2024-07-07 ----
[1] Fix League problems
    The league for Season 01 has been updated.
    Season 02 will start next Monday(2024-7-8).
        (League 2 weeks -> calculation after 3 days
            -> new league starts next Monday)


2024-07-02 ----
[1] 🐞Bug Notice : League is not working
    - Season 01 of the league is over, but season 02 is not working properly.
    I am looking into the issue.

[2] Fixed bug causing season to be 1 week instead of 2 weeks.


2024-06-23 -----
[1] Adding New Features
    - Add multilingual translation (Beta).
    - Add Searchable Combo Box.
    - Sort groups by number of members.



2024-06-20 -----
[1] First release (Fork version)
    - Developing a new server
    - Create new database
    - Update all server URLs
    - Added auto-update function for leagues
    - Partial rewrite of menu
    - Rewrite descriptions
    - Updated license header
    - Resolved issue with Mac options
    - Changes to notification system


The Github repository is still in preparation.
(Since there are security issues with the server)

"""
