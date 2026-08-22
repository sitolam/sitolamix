

from aqt import QComboBox, QGridLayout
from .create_icon import create_leaderboard_icon

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from  .Leaderboard import start_main

LEAGUE_NAMES = ["Alpha", "Beta", "Gamma","Delta" ]


def set_toggle_league(self:"start_main"):

    custom_gridLayout = self.dialog.custom_gridLayout =  QGridLayout()
    toggle_leagues = self.dialog.toggle_leagues = QComboBox(self.dialog.tab_5)
    toggle_leagues.setObjectName("toggle_leagues")

    # QGridLayout.addWidget(widget, row, column, rowSpan, columnSpan)
    # widget: ｸﾞﾘｯﾄﾞに追加するｳｨｼﾞｪｯﾄ
    # row: ｳｨｼﾞｪｯﾄを配置する行のｲﾝﾃﾞｯｸｽ（0から始まる）
    # column: ｳｨｼﾞｪｯﾄを配置する列のｲﾝﾃﾞｯｸｽ（0から始まる）
    # rowSpan: ｳｨｼﾞｪｯﾄが占める行の数｡ﾃﾞﾌｫﾙﾄは1
    # columnSpan: ｳｨｼﾞｪｯﾄが占める列の数｡ﾃﾞﾌｫﾙﾄは1

    custom_gridLayout.addWidget(toggle_leagues, 0, 0)
    custom_gridLayout.setColumnStretch(0, 1)
    custom_gridLayout.setColumnStretch(1, 4)
    # custom_gridLayout.setColumnStretch(2, 1)

    # ﾘｰｸﾞのｸﾞﾘｯﾄﾞﾚｲｱｳﾄを下へずらす
    existing_layout = self.dialog.gridLayout_2.itemAtPosition(0, 0).layout()
    self.dialog.gridLayout_2.removeItem(existing_layout)
    self.dialog.gridLayout_2.addLayout(existing_layout, 1, 0)

    # 新しいｸﾞﾘｯﾄﾞを追加
    self.dialog.gridLayout_2.addLayout(custom_gridLayout, 0, 0)

    now_user_league = self.user_league_name

    def switch_league(index):
        if index is None:
            index = toggle_leagues.currentIndex()
        text = toggle_leagues.itemData(index)


        from .rebuild_league import rebuild_league_table
        from .add_pic_country_league import set_pic_league_tab
        league_name = text
        leagues = self.save_all_users_ranking.get_ranking_by_league(league_name)
        rebuild_league_table(self, leagues ,text)
        ### HIDDEN ###
        for i in range(self.dialog.League.rowCount()):
            item = self.dialog.League.item(i, 1).text().split(" |")[0]
            if item in self.config['hidden_users']:
                self.dialog.League.hideRow(i) # does not work well
                self.dialog.League.setRowHeight(i, 0) # work
        set_pic_league_tab(self)

        from .change_leaderboard_size import change_board_size
        change_board_size(self, self.dialog.League)

        if self.config.get("add_pic_country_and_league", True) and self.config.get("gamification_mode", True):
            from .custom_column import custom_column_size
            custom_column_size(self, self.dialog.League)

        # for debug only ------
        from .hide_users_name import hide_all_users_name
        hide_all_users_name(self)
        # ----------------------


    league_icons = {
    "Delta": "delta_12.png",
    "Gamma": "gamma_12.png",
    "Beta": "beta_12.png",
    "Alpha": "alpha_12.png",
    }

    league_stars = {
    "Delta": "★",
    "Gamma": "★★",
    "Beta": "★★★",
    "Alpha": "★★★★",
    }

    for item in range(0, len(LEAGUE_NAMES)):
        # toggle_leagues.addItem("")
        # toggle_leagues.setItemText(item, LEAGUE_NAMES[item])
        league_name = LEAGUE_NAMES[item]

        stars = league_stars.get(league_name, "★")
        display_name = f"{league_name} {stars}"

        league_icon_filename = league_icons.get(league_name, "delta_12.png")
        league_icon = create_leaderboard_icon(file_name=league_icon_filename, icon_type="shield")
        # toggle_leagues.setItemText(league_icon, item, item)
        toggle_leagues.addItem(league_icon, display_name, league_name)


    index = toggle_leagues.findData(now_user_league)
    if index != -1:
        toggle_leagues.setCurrentIndex(index)

    # toggle_leagues.setCurrentText(now_user_league)

    # toggle_leagues.currentTextChanged.connect(switch_league)
    toggle_leagues.currentIndexChanged.connect(switch_league)

