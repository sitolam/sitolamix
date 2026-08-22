
import datetime
from aqt import QCursor, QHeaderView, QIcon, QTableWidgetItem, Qt, mw
from os.path import dirname, join

from .check_user_rank import compute_user_rank
from .custom_shige.country_dict import COUNTRY_FLAGS
from .create_icon import create_leaderboard_icon


from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .Leaderboard import start_main

TOOLTIP_ICON_SIZE = 64
LEAGUE_NAMES = ["Delta", "Gamma", "Beta", "Alpha" ]


### GOLOBAL ICONS ###


#### LEAGUE IOCONS ####

def set_pic_league_tab(self:"start_main"):

    ### League tab ###
    self.dialog.League.setColumnCount(7)

    new_column_index = self.dialog.League.columnCount() # start 1
    self.dialog.League.setColumnCount(new_column_index + 2) # start 0

    if self.config.get("gamification_mode", True) :
        trophy_item = QTableWidgetItem("🏆Rank")
    else:
        trophy_item = QTableWidgetItem("🏆")


    trophy_item.setToolTip("League")
    self.dialog.League.setHorizontalHeaderItem(new_column_index, trophy_item) # start 1

    self.dialog.League.setColumnWidth(new_column_index+1, 15)
    self.dialog.League.horizontalHeader().setSectionResizeMode(new_column_index+1, QHeaderView.ResizeMode.Fixed)


    if self.config.get("gamification_mode", True) :
        globe_item = QTableWidgetItem("🌎️Country")
    else:
        globe_item = QTableWidgetItem("🌎️")

    globe_item.setToolTip("Country")
    globe_item.setTextAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
    self.dialog.League.setHorizontalHeaderItem(new_column_index + 1, globe_item) # start 1

    self.dialog.League.viewport().setCursor(QCursor(Qt.CursorShape.ArrowCursor))

    self.dialog.League.setColumnWidth(new_column_index, 15)
    self.dialog.League.horizontalHeader().setSectionResizeMode(new_column_index, QHeaderView.ResizeMode.Fixed)


    total_rows = self.dialog.League.rowCount()

    country_icons = {}

    self.user_icons_downloader.execution_count = 0

    for i in range(self.dialog.League.rowCount()):
        item = self.dialog.League.item(i, 1).text().split(" |")[0]


        for leaderbord_lists in self.response[0]:
            if item == leaderbord_lists[0]:
                country = leaderbord_lists[7]
                # qtab_c = QTableWidgetItem(COUNTRY_FLAGS.get(country, " "))
                flag_icon_file_path = COUNTRY_FLAGS.get(country.replace(" ", ""), "pirate.png")
                if flag_icon_file_path == "pirate.png":
                    tooltip_country = "Pirate"
                else:
                    tooltip_country = country

                # country_icon = QIcon(join(addon_path, "custom_shige", "flags", c_svg_file))
                country_icon = create_leaderboard_icon(file_name=flag_icon_file_path,
                                                    icon_type="flag")

                country_icons[item] = [country_icon, country]

                qtab_c = QTableWidgetItem()
                qtab_c.setIcon(country_icon)

                if self.config.get("gamification_mode", True):
                    qtab_c.setText(tooltip_country)


                first_column_item = self.dialog.League.item(i, 0)
                if first_column_item:
                    qtab_c.setBackground(first_column_item.background())

                qtab_c.setToolTip(f"{tooltip_country}")
                self.dialog.League.setItem(i, new_column_index+1, qtab_c)
                # self.dialog.League.setColumnWidth(new_column_index+1, 15)
                # self.dialog.League.horizontalHeader().setSectionResizeMode(new_column_index+1, QHeaderView.ResizeMode.Fixed)

        for league_lists in self.response[1]:
            if item == league_lists[0]:
                league_name = league_lists[5]

                league_icons = {
                "Delta": "delta_04.png",
                "Gamma": "gamma_04.png",
                "Beta": "beta_04.png",
                "Alpha": "alpha_04.png",
                }

                ranks_file_number = {
                    10: 12,
                    20: 11,
                    30: 10,
                    40: 9,
                    50: 8,
                    60: 7,
                    70: 6,
                    80: 5,
                    90: 2,
                    100: 1,
                }

                rank_number, rank_a_f, league_percentage_text  = compute_user_rank(i + 1, total_rows)
                # rank_number, rank_a_f, league_percentage_text  = compute_user_rank(self, item)
                new_number = ranks_file_number[rank_number]

                # league_percentage_text = f" {i + 1}, {text}"

                league_icon_filename = league_icons.get(league_name, "delta_04.png").replace("_04", f"_{new_number:02}")
                # print(league_icon_filename)

                league_icon = create_leaderboard_icon(file_name=league_icon_filename,
                                                    icon_type="shield")
                league_icon_path = league_icon.get_path()

                # league_icon = create_rounded_icon(league_icons.get(league_name, "delta_04.png"))

                qtab_le = QTableWidgetItem()
                qtab_le.setIcon(league_icon)

                if self.config.get("gamification_mode", True):
                    qtab_le.setText(f" {rank_a_f} ")

                first_column_item = self.dialog.League.item(i, 0)
                if first_column_item:
                    qtab_le.setBackground(first_column_item.background())




                header_02 = self.dialog.League.horizontalHeaderItem(2).text()
                header_03 = self.dialog.League.horizontalHeaderItem(3).text()
                header_04 = self.dialog.League.horizontalHeaderItem(4).text()
                header_05 = self.dialog.League.horizontalHeaderItem(5).text()
                header_06 = self.dialog.League.horizontalHeaderItem(6).text()


                league_xp = self.dialog.League.item(i, 2).text()
                league_xp = "{:,}".format(int(league_xp))
                league_time = self.dialog.League.item(i, 3).text()

                league_review = self.dialog.League.item(i, 4).text()
                league_review = "{:,}".format(int(league_review))

                league_retention = self.dialog.League.item(i, 5).text()
                league_day_study = self.dialog.League.item(i, 6).text()

                country_icon_Qicon, country_name = country_icons[item]

                if not country_name.replace(" ", "") in COUNTRY_FLAGS:
                    country_name = "Pirate"

                country_icon_path = country_icon_Qicon.get_path()

                addon_path = dirname(__file__)
                country_icon_path = join(addon_path, "custom_shige", "flags", country_icon_path)

                star_icon = create_leaderboard_icon(file_name="star_icon.png", icon_type="other")
                star_icon_img = f'<img src="{star_icon.get_path()}" width="20" height="20" >'

                league_stars = {
                "Delta": f'{star_icon_img}',
                "Gamma": f'{star_icon_img*2}',
                "Beta": f'{star_icon_img*3}',
                "Alpha": f'{star_icon_img*4}',
                }

                tooltip_text = f"""
                <table cellpadding="10">
                    <tr>
                        <td align="center">
                            <!--PLACEHOLDER-->
                            <img src="{league_icon_path}" width="{TOOLTIP_ICON_SIZE}" height="{TOOLTIP_ICON_SIZE}">
                            <br>
                            <span style="font-size: 16px; font-weight: bold;">
                                {league_stars[league_name]}
                                <br>
                                {league_name.upper()}
                                <span style="font-size: 16px; font-weight: bold;">
                                <br>
                                SEASON :&nbsp;{rank_a_f}
                                </span>
                            </span>
                            <br>
                            <span style="font-size: 16px; ">
                                <b>{i + 1}</b> / {total_rows}
                            </span>
                            <br>
                            <span style="font-size: 12px ;">
                                {league_percentage_text}
                            </span>

                        </td>
                        <td>
                            <span style="font-size: 25px; font-weight: bold;">
                                {item}<br>
                            </span>
                            <img src="{country_icon_path}" width="18" height="18" >
                            <span style="font-size: 20px;">
                                <b>&nbsp;{country_name}</b>
                            </span>
                            <span style="font-size: 16px;">
                                <br>
                                {header_02} : <b>{league_xp}</b>&nbsp;xp<br>
                                {header_03} : <b>{league_time}</b>&nbsp;min<br>
                                {header_04} : <b>{league_review}</b>&nbsp;cards<br>
                                {header_05} : <b>{league_retention}</b>&nbsp;%<br>
                                {header_06} : <b>{league_day_study}</b>&nbsp;%<br>
                            </span>
                            <span style="font-size: 12px; color: grey;">
                                Double click on user for more info.
                            </span>
                        </td>
                    </tr>
                </table>
                """

                qtab_le.setToolTip(tooltip_text)
                self.dialog.League.setItem(i, new_column_index, qtab_le)

                def apply_tooltip_to_row(tooltip_text):
                    column_count = self.dialog.League.columnCount()
                    for column in range(column_count):
                        item = self.dialog.League.item(i, column)
                        if item is not None:
                            item.setToolTip(tooltip_text)

                apply_tooltip_to_row(tooltip_text)
                # self.dialog.League.viewport().setProperty("cursor", Qt.CursorShape.ArrowCursor)
                # self.dialog.League.setCursor(QCursor(Qt.CursorShape.ArrowCursor))

                # self.dialog.League.viewport().setCursor(QCursor(Qt.CursorShape.ArrowCursor))
                # self.dialog.League.setColumnWidth(new_column_index, 15)
                # self.dialog.League.horizontalHeader().setSectionResizeMode(new_column_index, QHeaderView.ResizeMode.Fixed)

                if self.user_icons_downloader.execution_count < self.user_icons_downloader.max_executions:
                    self.user_icons_downloader.add_make_path_and_icons_list(
                    # user_icons_downloader.binary_get_icon_direct(
                        tab_widget=self.dialog.League,
                        row_number=i,
                        user_name=item,
                        size=TOOLTIP_ICON_SIZE)
                    self.user_icons_downloader.execution_count += 1



    # # for column_index in range(2, 7):
    # for column_index in range(3, 7): # XPを除外
    #     header_item = self.dialog.League.horizontalHeaderItem(column_index)
    #     if header_item:
    #         text = header_item.text()
    #         font_metrics = self.dialog.League.fontMetrics()
    #         text_width = font_metrics.horizontalAdvance(text) + 30
    #         # print(f"Header text: {text}, Column {column_index}: Text width = {text_width}")
    #         self.dialog.League.setColumnWidth(column_index, text_width)
    #         self.dialog.League.horizontalHeader().setSectionResizeMode(column_index, QHeaderView.ResizeMode.Fixed)
    #         actual_width = self.dialog.League.columnWidth(column_index)
    #         # print(f"Column {column_index}: Set width = {actual_width}")



# def add_pic_country_and_league(self:"start_main"): # 使ってない

#     new_column_index = self.dialog.Global_Leaderboard.columnCount() # start 1
#     self.dialog.Global_Leaderboard.setColumnCount(new_column_index + 2) # start 0

#     ### global tab ###

#     trophy_item = QTableWidgetItem("🏆")
#     trophy_item.setToolTip("League")
#     self.dialog.Global_Leaderboard.setHorizontalHeaderItem(new_column_index, trophy_item) # start 1

#     globe_item = QTableWidgetItem("🌎️")
#     globe_item.setToolTip("Country")
#     self.dialog.Global_Leaderboard.setHorizontalHeaderItem(new_column_index + 1, globe_item) # start 1


#     # for column_index in range(self.dialog.Global_Leaderboard.columnCount()):
#     for column_index in range(2, self.dialog.Global_Leaderboard.columnCount()):
#         self.dialog.Global_Leaderboard.horizontalHeader().setSectionResizeMode(column_index, QHeaderView.ResizeMode.Interactive)

#     total_rows = self.dialog.Global_Leaderboard.rowCount()
#     country_icons = {}


#     for i in range(self.dialog.Global_Leaderboard.rowCount()):
#         item = self.dialog.Global_Leaderboard.item(i, 1).text().split(" |")[0]

#         for leaderbord_lists in self.response[0]:
#             if item == leaderbord_lists[0]:
#                 country = leaderbord_lists[7]
#                 # qtab_c = QTableWidgetItem(COUNTRY_FLAGS.get(country, " "))
#                 flag_icon_file_path = COUNTRY_FLAGS.get(country.replace(" ", ""), "pirate.png")
#                 if flag_icon_file_path == "pirate.png":
#                     tooltip_country = "Pirate"
#                 else:
#                     tooltip_country = country

#                 # country_icon = QIcon(join(addon_path, "custom_shige", "flags", c_svg_file))
#                 country_icon = create_leaderboard_icon(file_name=flag_icon_file_path,
#                                                     icon_type="flag")

#                 country_icon = create_leaderboard_icon(file_name=flag_icon_file_path,
#                                                     icon_type="flag")

#                 country_icons[item] = [country_icon, country]



#                 qtab_c = QTableWidgetItem()
#                 qtab_c.setIcon(country_icon)

#                 first_column_item = self.dialog.Global_Leaderboard.item(i, 0)
#                 if first_column_item:
#                     qtab_c.setBackground(first_column_item.background())


#                 qtab_c.setToolTip(f"{tooltip_country}")
#                 self.dialog.Global_Leaderboard.setItem(i, new_column_index+1, qtab_c)
#                 self.dialog.Global_Leaderboard.setColumnWidth(new_column_index+1, 15)
#                 self.dialog.Global_Leaderboard.horizontalHeader().setSectionResizeMode(new_column_index+1, QHeaderView.ResizeMode.Fixed)


#         for league_lists in self.response[1]:
#             if item == league_lists[0]:
#                 league_name = league_lists[5]

#                 league_icons = {
#                 "Delta": "delta_04.png",
#                 "Gamma": "gamma_04.png",
#                 "Beta": "beta_04.png",
#                 "Alpha": "alpha_04.png",
#                 }


#                 ranks_file_number = {
#                     10: 12,
#                     20: 11,
#                     30: 10,
#                     40: 9,
#                     50: 8,
#                     60: 7,
#                     70: 6,
#                     80: 5,
#                     90: 2,
#                     100: 1,
#                 }

#                 rank_number, rank_a_f, league_percentage_text  = compute_user_rank(i + 1, total_rows)
#                 # rank_number, rank_a_f, league_percentage_text  = compute_user_rank(self, item)
#                 new_number = ranks_file_number[rank_number]

#                 # league_percentage_text = f" {i + 1}, {text}"

#                 league_icon_filename = league_icons.get(league_name, "delta_04.png").replace("_04", f"_{new_number:02}")

#                 # qtab_le = QTableWidgetItem(league_icons.get(league_name, " "))

#                 league_icon = create_leaderboard_icon(file_name=league_icon_filename,
#                                                     icon_type="hexagon")
#                 league_icon_path = league_icon.get_path()


#                 qtab_le = QTableWidgetItem()
#                 qtab_le.setIcon(league_icon)

#                 league_icon_path = league_icon.get_path()

#                 star_icon = create_leaderboard_icon(file_name="star_icon.png", icon_type="other")
#                 star_icon_img = f'<img src="{star_icon.get_path()}" width="20" height="20" >'

#                 league_stars = {
#                 "Delta": f'{star_icon_img}',
#                 "Gamma": f'{star_icon_img*2}',
#                 "Beta": f'{star_icon_img*3}',
#                 "Alpha": f'{star_icon_img*4}',
#                 }


#                 first_column_item = self.dialog.Global_Leaderboard.item(i, 0)
#                 if first_column_item:
#                     qtab_le.setBackground(first_column_item.background())

#                 qtab_le.setToolTip(f"{league_name}")
#                 self.dialog.Global_Leaderboard.setItem(i, new_column_index, qtab_le)
#                 self.dialog.Global_Leaderboard.setColumnWidth(new_column_index, 15)
#                 self.dialog.Global_Leaderboard.horizontalHeader().setSectionResizeMode(new_column_index, QHeaderView.ResizeMode.Fixed)


#                 rank_number, rank_a_f, global_percentage_text  = compute_user_rank(i + 1, total_rows)

#                 country_icon_Qicon, country_name = country_icons[item]

#                 if not country_name.replace(" ", "") in COUNTRY_FLAGS:
#                     country_name = "Pirate"

#                 country_icon_path = country_icon_Qicon.get_path()

#                 header_02 = self.dialog.Global_Leaderboard.horizontalHeaderItem(2).text()
#                 header_03 = self.dialog.Global_Leaderboard.horizontalHeaderItem(3).text()
#                 header_04 = self.dialog.Global_Leaderboard.horizontalHeaderItem(4).text()
#                 header_05 = self.dialog.Global_Leaderboard.horizontalHeaderItem(5).text()
#                 header_06 = self.dialog.Global_Leaderboard.horizontalHeaderItem(6).text()


#                 global_02 = self.dialog.Global_Leaderboard.item(i, 2).text()
#                 global_03 = self.dialog.Global_Leaderboard.item(i, 3).text()
#                 global_04 = self.dialog.Global_Leaderboard.item(i, 4).text()
#                 global_05 = self.dialog.Global_Leaderboard.item(i, 5).text()
#                 global_06 = self.dialog.Global_Leaderboard.item(i, 6).text()




#                 tooltip_text = f"""
#                 <table cellpadding="10">
#                     <tr>
#                         <td align="center">
#                             <img src="{league_icon_path}" width="{TOOLTIP_ICON_SIZE}" height="{TOOLTIP_ICON_SIZE}">
#                             <br>
#                             <span style="font-size: 16px; font-weight: bold;">
#                                 {league_stars[league_name]}
#                                 <br>
#                                 {league_name.upper()}
#                                 <br>
#                                 <span style="font-size: 16px; font-weight: bold;">
                                
#                                     TODAY :&nbsp;{rank_a_f}
#                                 </span>
#                             </span>
#                             <br>
#                             <span style="font-size: 16px; ">
#                                 <b>{i + 1}</b> / {total_rows}
#                             </span>
#                             <br>
#                             <span style="font-size: 12px ;">
#                                 {global_percentage_text}
#                             </span>

#                         </td>
#                         <td>
#                             <span style="font-size: 25px; font-weight: bold;">
#                                 {item}<br>
#                             </span>
#                             <img src="{country_icon_path}" width="18" height="18" >
#                             <span style="font-size: 20px;">
#                                 <b>&nbsp;{country_name}</b>
#                             </span>
#                             <span style="font-size: 16px;">
#                                 <br>
#                                 {header_02} : <b>{global_02}</b>&nbsp;<br>
#                                 {header_03} : <b>{global_03}</b>&nbsp;<br>
#                                 {header_04} : <b>{global_04}</b>&nbsp;<br>
#                                 {header_05} : <b>{global_05}</b>&nbsp;<br>
#                                 {header_06} : <b>{global_06}</b>&nbsp;<br>
#                             </span>
#                             <span style="font-size: 12px; color: grey;">
#                                 Double click on user for more info.
#                             </span>
#                         </td>
#                     </tr>
#                 </table>
#                 """





#                 def apply_tooltip_to_row(text):
#                     column_count = self.dialog.Global_Leaderboard.columnCount()
#                     for column in range(column_count):
#                         item = self.dialog.Global_Leaderboard.item(i, column)
#                         if item is not None:
#                             item.setToolTip(text)

#                 apply_tooltip_to_row(tooltip_text)
#                 self.dialog.Global_Leaderboard.viewport().setCursor(QCursor(Qt.CursorShape.ArrowCursor))

#                 self.dialog.Global_Leaderboard.setColumnWidth(new_column_index, 15)
#                 self.dialog.Global_Leaderboard.horizontalHeader().setSectionResizeMode(new_column_index, QHeaderView.ResizeMode.Fixed)








#     # for column_index in range(self.dialog.Global_Leaderboard.columnCount()):
#     #     self.dialog.Global_Leaderboard.horizontalHeader().setSectionResizeMode(column_index, QHeaderView.ResizeMode.Interactive)

#     for column_index in range(2, 7):
#         header_item = self.dialog.Global_Leaderboard.horizontalHeaderItem(column_index)
#         if header_item:
#             text = header_item.text()
#             font_metrics = self.dialog.Global_Leaderboard.fontMetrics()
#             text_width = font_metrics.horizontalAdvance(text) + 30
#             # print(f"Header text: {text}, Column {column_index}: Text width = {text_width}")
#             self.dialog.Global_Leaderboard.setColumnWidth(column_index, text_width)
#             self.dialog.Global_Leaderboard.horizontalHeader().setSectionResizeMode(column_index, QHeaderView.ResizeMode.Fixed)
#             actual_width = self.dialog.Global_Leaderboard.columnWidth(column_index)
#             # print(f"Column {column_index}: Set width = {actual_width}")

#     # self.dialog.Global_Leaderboard.resizeColumnsToContents()







# from aqt import QCursor, QHeaderView, QIcon, QTableWidgetItem, Qt, mw
# from os.path import dirname, join

# from .check_user_rank import compute_user_rank
# from .custom_shige.country_dict import COUNTRY_FLAGS
# from .create_icon import create_rounded_icon

# from typing import TYPE_CHECKING
# if TYPE_CHECKING:
#     from  .Leaderboard import start_main

# TOOLTIP_ICON_SIZE = 64
# LEAGUE_NAMES = ["Delta", "Gamma", "Beta", "Alpha" ]


# ### GOLOBAL ICONS ###

# def add_pic_country_and_league(self:"start_main"):

#     new_column_index = self.dialog.Global_Leaderboard.columnCount() # start 1
#     self.dialog.Global_Leaderboard.setColumnCount(new_column_index + 2) # start 0

#     ### global tab ###

#     trophy_item = QTableWidgetItem("🏆")
#     trophy_item.setToolTip("League")
#     self.dialog.Global_Leaderboard.setHorizontalHeaderItem(new_column_index, trophy_item) # start 1

#     globe_item = QTableWidgetItem("🌎️")
#     globe_item.setToolTip("Country")
#     self.dialog.Global_Leaderboard.setHorizontalHeaderItem(new_column_index + 1, globe_item) # start 1


#     # for column_index in range(self.dialog.Global_Leaderboard.columnCount()):
#     for column_index in range(2, self.dialog.Global_Leaderboard.columnCount()):
#         self.dialog.Global_Leaderboard.horizontalHeader().setSectionResizeMode(column_index, QHeaderView.ResizeMode.Interactive)

#     for i in range(self.dialog.Global_Leaderboard.rowCount()):
#         item = self.dialog.Global_Leaderboard.item(i, 1).text().split(" |")[0]
#         for league_lists in self.response[1]:
#             if item == league_lists[0]:
#                 league_name = league_lists[5]

#                 league_icons = {
#                 "Delta": "delta_04.png",
#                 "Gamma": "gamma_04.png",
#                 "Beta": "beta_04.png",
#                 "Alpha": "alpha_04.png",
#                 }

#                 # qtab_le = QTableWidgetItem(league_icons.get(league_name, " "))
#                 league_icon = create_rounded_icon(
#                     file_name=league_icons.get(league_name, "delta_04.png"),
#                     icon_type="shield"
#                     )

#                 qtab_le = QTableWidgetItem()
#                 qtab_le.setIcon(league_icon)

#                 first_column_item = self.dialog.Global_Leaderboard.item(i, 0)
#                 if first_column_item:
#                     qtab_le.setBackground(first_column_item.background())

#                 qtab_le.setToolTip(f"{league_name}")
#                 self.dialog.Global_Leaderboard.setItem(i, new_column_index, qtab_le)
#                 self.dialog.Global_Leaderboard.setColumnWidth(new_column_index, 15)
#                 self.dialog.Global_Leaderboard.horizontalHeader().setSectionResizeMode(new_column_index, QHeaderView.ResizeMode.Fixed)


#         for leaderbord_lists in self.response[0]:
#             if item == leaderbord_lists[0]:
#                 country = leaderbord_lists[7]
#                 # qtab_c = QTableWidgetItem(COUNTRY_FLAGS.get(country, " "))
#                 flag_icon_file_path = COUNTRY_FLAGS.get(country.replace(" ", ""), "pirate.png")
#                 if flag_icon_file_path == "pirate.png":
#                     tooltip_country = "Pirate"
#                 else:
#                     tooltip_country = country

#                 # country_icon = QIcon(join(addon_path, "custom_shige", "flags", c_svg_file))
#                 country_icon = create_rounded_icon(file_name=flag_icon_file_path,
#                                                     icon_type="flag")


#                 qtab_c = QTableWidgetItem()
#                 qtab_c.setIcon(country_icon)

#                 first_column_item = self.dialog.Global_Leaderboard.item(i, 0)
#                 if first_column_item:
#                     qtab_c.setBackground(first_column_item.background())


#                 qtab_c.setToolTip(f"{tooltip_country}")
#                 self.dialog.Global_Leaderboard.setItem(i, new_column_index+1, qtab_c)
#                 self.dialog.Global_Leaderboard.setColumnWidth(new_column_index+1, 15)
#                 self.dialog.Global_Leaderboard.horizontalHeader().setSectionResizeMode(new_column_index+1, QHeaderView.ResizeMode.Fixed)

#     # for column_index in range(self.dialog.Global_Leaderboard.columnCount()):
#     #     self.dialog.Global_Leaderboard.horizontalHeader().setSectionResizeMode(column_index, QHeaderView.ResizeMode.Interactive)

#     for column_index in range(2, 7):
#         header_item = self.dialog.Global_Leaderboard.horizontalHeaderItem(column_index)
#         if header_item:
#             text = header_item.text()
#             font_metrics = self.dialog.Global_Leaderboard.fontMetrics()
#             text_width = font_metrics.horizontalAdvance(text) + 30
#             # print(f"Header text: {text}, Column {column_index}: Text width = {text_width}")
#             self.dialog.Global_Leaderboard.setColumnWidth(column_index, text_width)
#             self.dialog.Global_Leaderboard.horizontalHeader().setSectionResizeMode(column_index, QHeaderView.ResizeMode.Fixed)
#             actual_width = self.dialog.Global_Leaderboard.columnWidth(column_index)
#             # print(f"Column {column_index}: Set width = {actual_width}")

#     # self.dialog.Global_Leaderboard.resizeColumnsToContents()





# #### LEAGUE IOCONS ####

# def set_pic_league_tab(self:"start_main"):

#     ### League tab ###

#     new_column_index = self.dialog.League.columnCount() # start 1
#     self.dialog.League.setColumnCount(new_column_index + 2) # start 0

#     trophy_item = QTableWidgetItem("🏆")
#     trophy_item.setToolTip("League")
#     self.dialog.League.setHorizontalHeaderItem(new_column_index, trophy_item) # start 1

#     globe_item = QTableWidgetItem("🌎️")
#     globe_item.setToolTip("Country")
#     self.dialog.League.setHorizontalHeaderItem(new_column_index + 1, globe_item) # start 1


#     total_rows = self.dialog.League.rowCount()

#     country_icons = {}


#     for i in range(self.dialog.League.rowCount()):
#         item = self.dialog.League.item(i, 1).text().split(" |")[0]


#         for leaderbord_lists in self.response[0]:
#             if item == leaderbord_lists[0]:
#                 country = leaderbord_lists[7]
#                 # qtab_c = QTableWidgetItem(COUNTRY_FLAGS.get(country, " "))
#                 flag_icon_file_path = COUNTRY_FLAGS.get(country.replace(" ", ""), "pirate.png")
#                 if flag_icon_file_path == "pirate.png":
#                     tooltip_country = "Pirate"
#                 else:
#                     tooltip_country = country

#                 # country_icon = QIcon(join(addon_path, "custom_shige", "flags", c_svg_file))
#                 country_icon = create_rounded_icon(file_name=flag_icon_file_path,
#                                                     icon_type="flag")

#                 country_icons[item] = [country_icon, country]

#                 qtab_c = QTableWidgetItem()
#                 qtab_c.setIcon(country_icon)

#                 first_column_item = self.dialog.League.item(i, 0)
#                 if first_column_item:
#                     qtab_c.setBackground(first_column_item.background())

#                 qtab_c.setToolTip(f"{tooltip_country}")
#                 self.dialog.League.setItem(i, new_column_index+1, qtab_c)
#                 self.dialog.League.setColumnWidth(new_column_index+1, 15)
#                 self.dialog.League.horizontalHeader().setSectionResizeMode(new_column_index+1, QHeaderView.ResizeMode.Fixed)

#         for league_lists in self.response[1]:
#             if item == league_lists[0]:
#                 league_name = league_lists[5]

#                 league_icons = {
#                 "Delta": "delta_04.png",
#                 "Gamma": "gamma_04.png",
#                 "Beta": "beta_04.png",
#                 "Alpha": "alpha_04.png",
#                 }

#                 ranks_file_number = {
#                     10: 12,
#                     20: 11,
#                     30: 10,
#                     40: 9,
#                     50: 8,
#                     60: 7,
#                     70: 6,
#                     80: 5,
#                     90: 2,
#                     100: 1,
#                 }

#                 rank_number, rank_a_f, league_percentage_text  = compute_user_rank(i + 1, total_rows)
#                 # rank_number, rank_a_f, league_percentage_text  = compute_user_rank(self, item)
#                 new_number = ranks_file_number[rank_number]

#                 # league_percentage_text = f" {i + 1}, {text}"

#                 league_icon_filename = league_icons.get(league_name, "delta_04.png").replace("_04", f"_{new_number:02}")
#                 # print(league_icon_filename)

#                 league_icon = create_rounded_icon(file_name=league_icon_filename,
#                                                     icon_type="shield")
#                 league_icon_path = league_icon.get_path()

#                 # league_icon = create_rounded_icon(league_icons.get(league_name, "delta_04.png"))

#                 qtab_le = QTableWidgetItem()
#                 qtab_le.setIcon(league_icon)

#                 first_column_item = self.dialog.League.item(i, 0)
#                 if first_column_item:
#                     qtab_le.setBackground(first_column_item.background())


#                 league_xp = self.dialog.League.item(i, 2).text()
#                 league_xp = "{:,}".format(int(league_xp))
#                 league_time = self.dialog.League.item(i, 3).text()

#                 league_review = self.dialog.League.item(i, 4).text()
#                 league_review = "{:,}".format(int(league_review))

#                 league_retention = self.dialog.League.item(i, 5).text()
#                 league_day_study = self.dialog.League.item(i, 6).text()

#                 country_icon_Qicon, country_name = country_icons[item]

#                 if not country_name.replace(" ", "") in COUNTRY_FLAGS:
#                     country_name = "Pirate"

#                 country_icon_path = country_icon_Qicon.get_path()

#                 addon_path = dirname(__file__)
#                 country_icon_path = join(addon_path, "custom_shige", "flags", country_icon_path)

#                 star_icon = create_rounded_icon(file_name="star_icon.png", icon_type="other")
#                 star_icon_img = f'<img src="{star_icon.get_path()}" width="20" height="20" >'

#                 league_stars = {
#                 "Delta": f'{star_icon_img}',
#                 "Gamma": f'{star_icon_img*2}',
#                 "Beta": f'{star_icon_img*3}',
#                 "Alpha": f'{star_icon_img*4}',
#                 }


#                 tooltip_text = f"""
#                 <table cellpadding="10">
#                     <tr>
#                         <td align="center">
#                             <img src="{league_icon_path}" width="{TOOLTIP_ICON_SIZE}" height="{TOOLTIP_ICON_SIZE}">
#                             <br>
#                             <span style="font-size: 16px; font-weight: bold;">
#                                 {league_stars[league_name]}
#                                 <br>
#                                 {league_name.upper()}
#                                 <span style="font-size: 16px; font-weight: bold;">
#                                     :&nbsp;{rank_a_f}
#                                 </span>
#                             </span>
#                             <br>
#                             <span style="font-size: 16px; ">
#                                 <b>{i + 1}</b> / {total_rows}
#                             </span>
#                             <br>
#                             <span style="font-size: 12px ;">
#                                 {league_percentage_text}
#                             </span>

#                         </td>
#                         <td>
#                             <span style="font-size: 25px; font-weight: bold;">
#                                 {item}<br>
#                             </span>
#                             <img src="{country_icon_path}" width="18" height="18" >
#                             <span style="font-size: 20px;">
#                                 <b>&nbsp;{country_name}</b>
#                             </span>
#                             <span style="font-size: 16px;">
#                                 <br>
#                                 XP : <b>{league_xp}</b>&nbsp;xp<br>
#                                 TIME : <b>{league_time}</b>&nbsp;min<br>
#                                 REVIEW : <b>{league_review}</b>&nbsp;cards<br>
#                                 RETENTION : <b>{league_retention}</b>&nbsp;%<br>
#                                 DAY STUDY : <b>{league_day_study}</b>&nbsp;%<br>
#                             </span>
#                             <span style="font-size: 12px; color: grey;">
#                                 Double click on user for more info.
#                             </span>
#                         </td>
#                     </tr>
#                 </table>
#                 """

#                 qtab_le.setToolTip(tooltip_text)
#                 self.dialog.League.setItem(i, new_column_index, qtab_le)

#                 def apply_tooltip_to_row(tooltip_text):
#                     column_count = self.dialog.League.columnCount()
#                     for column in range(column_count):
#                         item = self.dialog.League.item(i, column)
#                         if item is not None:
#                             item.setToolTip(tooltip_text)

#                 apply_tooltip_to_row(tooltip_text)
#                 # self.dialog.League.viewport().setProperty("cursor", Qt.CursorShape.ArrowCursor)
#                 # self.dialog.League.setCursor(QCursor(Qt.CursorShape.ArrowCursor))
#                 self.dialog.League.viewport().setCursor(QCursor(Qt.CursorShape.ArrowCursor))

#                 self.dialog.League.setColumnWidth(new_column_index, 15)
#                 self.dialog.League.horizontalHeader().setSectionResizeMode(new_column_index, QHeaderView.ResizeMode.Fixed)


#     # for column_index in range(2, 7):
#     for column_index in range(3, 7): # XPを除外
#         header_item = self.dialog.League.horizontalHeaderItem(column_index)
#         if header_item:
#             text = header_item.text()
#             font_metrics = self.dialog.League.fontMetrics()
#             text_width = font_metrics.horizontalAdvance(text) + 30
#             # print(f"Header text: {text}, Column {column_index}: Text width = {text_width}")
#             self.dialog.League.setColumnWidth(column_index, text_width)
#             self.dialog.League.horizontalHeader().setSectionResizeMode(column_index, QHeaderView.ResizeMode.Fixed)
#             actual_width = self.dialog.League.columnWidth(column_index)
#             # print(f"Column {column_index}: Set width = {actual_width}")

