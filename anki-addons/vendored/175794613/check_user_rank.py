# Copyright (C) Shigeyuki <http://patreon.com/Shigeyuki>
# License: GNU AGPL version 3 or later <http://www.gnu.org/licenses/agpl.html>


class SaveUserRankings:
    def __init__(self):

        self.alpha_ranking = []
        self.beta_ranking = []
        self.gamma_ranking = []
        self.delta_ranking = []

        self.alpha_count = 0
        self.beta_count = 0
        self.gamma_count = 0
        self.delta_count = 0


    def save_user_rank(self, item):
        league_name = item[5]
        xp = item[1]

        if league_name == "Alpha":
            if xp != 0:
                self.alpha_count += 1
                self.alpha_ranking.append((item, self.alpha_count))

        elif league_name == "Beta":
            if xp != 0:
                self.beta_count += 1
                self.beta_ranking.append((item, self.beta_count))

        elif league_name == "Gamma":
            if xp != 0:
                self.gamma_count += 1
                self.gamma_ranking.append((item, self.gamma_count))

        elif league_name == "Delta":
            if xp != 0:
                self.delta_count += 1
                self.delta_ranking.append((item, self.delta_count))


    def get_user_item_and_rank(self, user_name):
        for ranking in [self.alpha_ranking, self.beta_ranking, self.gamma_ranking, self.delta_ranking]:
            for item, count in ranking:
                if user_name == item[0]:
                    league_name = item[5]
                    if league_name == "Alpha":
                        total_number = self.alpha_count
                    elif league_name == "Beta":
                        total_number = self.beta_count
                    elif league_name == "Gamma":
                        total_number = self.gamma_count
                    else:
                        total_number = self.delta_count
                    return count, total_number

        return 0, self.delta_count


    def get_ranking_by_league(self, league_name):
        if league_name == "Alpha":
            return self.alpha_ranking
        elif league_name == "Beta":
            return self.beta_ranking
        elif league_name == "Gamma":
            return self.gamma_ranking
        else:
            return self.delta_ranking


    def compute_user_rank(self, user_name):
        # not used yet
        number, total_users = self.get_user_item_and_rank(user_name)

        number = max(1, min(number, total_users))

        top_or_buttom_20_per = int((total_users / 100) * 20)
        top_80_per = total_users - top_or_buttom_20_per

        ranks = {
            10: [10, "A+", "(Top 10%)"],
            20: [20, "A", "(Top 10-20%)"],
            30: [30, "B+", "(Top 20-30%)"],
            40: [40, "B", "(Mid 30-40%)"],
            50: [50, "C+", "(Mid 40-50%)"],
            60: [60, "C", "(Mid 50-60%)"],
            70: [70, "D+", "(Lower 60-70%)"],
            80: [80, "D", "(Lower 70-80%)"],
            90: [90, "E", "(Bottom 80-90%)"],
            100: [100, "F", "(Bottom 90-100%)"]
        }

        if total_users <= 10 and number <= 10:
            return ranks[number * 10]

        # Top 20%
        if number <= top_or_buttom_20_per:
            if number > (top_or_buttom_20_per // 2):
                return ranks[20]
            else:
                return ranks[10]


        top_30_to_80 = total_users - (top_or_buttom_20_per)*2

        # Top 30% - 80%
        if number <= top_80_per:
            if number <= top_or_buttom_20_per + (top_30_to_80 // 6):
                return ranks[30]
            elif number <= top_or_buttom_20_per + (top_30_to_80 // 6) * 2:
                return ranks[40]
            elif number <= top_or_buttom_20_per + (top_30_to_80 // 6) * 3:
                return ranks[50]
            elif number <= top_or_buttom_20_per + (top_30_to_80 // 6) * 4:
                return ranks[60]
            elif number <= top_or_buttom_20_per + (top_30_to_80 // 6) * 5:
                return ranks[70]
            else:
                return ranks[80]

        # Bottom 20%
        if number > top_80_per:
            if number > (total_users - (top_or_buttom_20_per // 2)):
                return ranks[100]
            else:
                return ranks[90]

        return ranks[50] # default: something error



def compute_user_rank(number, total_users):
    number = max(1, min(number, total_users))

    top_or_buttom_20_per = int((total_users / 100) * 20)
    top_80_per = total_users - top_or_buttom_20_per

    # ranks = {
    #     10: [10, "A+", "(Top 10%)"],
    #     20: [20, "A", "(Top 10-20%)"],
    #     30: [30, "B+", "(Top 20-30%)"],
    #     40: [40, "B", "(Mid 30-40%)"],
    #     50: [50, "C+", "(Mid 40-50%)"],
    #     60: [60, "C", "(Mid 50-60%)"],
    #     70: [70, "D+", "(Lower 60-70%)"],
    #     80: [80, "D", "(Lower 70-80%)"],
    #     90: [90, "E", "(Bottom 80-90%)"],
    #     100: [100, "F", "(Bottom 90-100%)"]
    # }

    ranks = {
        10: [10, "A+", "(Top 10%)"],
        20: [20, "A", "(Top 10-20%)"],
        30: [30, "B+", "(Top 20-30%)"],
        40: [40, "B", "(Mid 30-40%)"],
        50: [50, "C+", "(Mid 40-50%)"],
        60: [60, "C", "(Mid 50-60%)"],
        70: [70, "D+", "(Lower 60-70%)"],
        80: [80, "D", "(Lower 70-80%)"],
        90: [90, "E", "(Bottom 80-90%)"],
        100: [100, "F", "(Bottom 90-100%)"]
    }

    if total_users <= 10 and number <= 10:
        return ranks[number * 10]


    # Top 20%
    if number <= top_or_buttom_20_per:
        if number > (top_or_buttom_20_per // 2):
            return ranks[20]
        else:
            return ranks[10]


    top_30_to_80 = total_users - (top_or_buttom_20_per)*2

    # Top 30% - 80%
    if number <= top_80_per:
        if number <= top_or_buttom_20_per + (top_30_to_80 // 6):
            return ranks[30]
        elif number <= top_or_buttom_20_per + (top_30_to_80 // 6) * 2:
            return ranks[40]
        elif number <= top_or_buttom_20_per + (top_30_to_80 // 6) * 3:
            return ranks[50]
        elif number <= top_or_buttom_20_per + (top_30_to_80 // 6) * 4:
            return ranks[60]
        elif number <= top_or_buttom_20_per + (top_30_to_80 // 6) * 5:
            return ranks[70]
        else:
            return ranks[80]

    # Bottom 20%
    if number > top_80_per:
        if number > (total_users - (top_or_buttom_20_per // 2)):
            return ranks[100]
        else:
            return ranks[90]

    return ranks[50] # default: something error






# sorted_all_users = {
#     'Delta': {},
#     'Gamma': {},
#     'Beta': {},
#     'Alpha': {}
# }


# def get_users_rank_dict(self, item_user_name):

#     for item in self.response[1]:
#         username = item[0]
#         xp = item[1]
#         league_name = item[5]

#         reviews = item[2]
#         time_spend = item[3]
#         retention = item[4]
#         days_learned = item[7]

#         if xp != 0:
#             sorted_all_users[league_name][username] = {
#                 'xp': xp,
#                 'reviews': reviews,
#                 'time_spend': time_spend,
#                 'retention': retention,
#                 'days_learned': days_learned
#             }

#     alpha_ranking = []
#     beta_ranking = []
#     gamma_ranking = []
#     delta_ranking = []

#     # xpが高い順に取得
#     sorted_response = sorted(self.response[1], key=lambda item: item[1], reverse=True)

#     for item in sorted_response:
#         user = item[0]
#         league_name = item[5]
#         xp = item[1]


#         if league_name == "Alpha":
#             if xp != 0:
#                 alpha_ranking.append(user)

#         if league_name == "Beta":
#             if xp != 0:
#                 beta_ranking.append(user)

#         if league_name == "Gamma":
#             if xp != 0:
#                 gamma_ranking.append(user)

#         if league_name == "Delta":
#             if xp != 0:
#                 delta_ranking.append(user)


#     counter = 1
#     for i in alpha_ranking:
#         save_user_rank(i, "Alpha", counter)
#         counter += 1

#     counter = 1
#     for i in beta_ranking:
#         save_user_rank(i, "Beta", counter)
#         counter += 1

#     counter = 1
#     for i in gamma_ranking:
#         save_user_rank(i, "Gamma", counter)
#         counter += 1

#     counter = 1
#     for i in delta_ranking:
#         save_user_rank(i, "Delta", counter)
#         counter += 1







# # ﾃｽﾄ
# total_users = 20
# rank_counts = {
#     "A+": 0,
#     "A": 0,
#     "B+": 0,
#     "B": 0,
#     "C+": 0,
#     "C": 0,
#     "D+": 0,
#     "D": 0,
#     "E": 0,
#     "F": 0
# }

# for i in range(1, total_users + 1):
#     rank = compute_user_rank(i, total_users)[1]
#     rank_counts[rank] += 1
#     print(f"{i} : {compute_user_rank(i, total_users)}")

# for rank, count in rank_counts.items():
#     print(f"{rank}: {count} users")



# import random
# import time


# rank_counts_template = {
#     "A+ (Top 10%)": 0,
#     "A (Top 10-20%)": 0,
#     "B+ (Top 20-30%)": 0,
#     "B (Mid 30-40%)": 0,
#     "C+ (Mid 40-50%)": 0,
#     "C (Mid 50-60%)": 0,
#     "D+ (Lower 60-70%)": 0,
#     "D (Lower 70-80%)": 0,
#     "E (Bottom 80-90%)": 0,
#     "F (Bottom 90-100%)": 0
# }


# random_total_users = [random.randint(0, 3000) for _ in range(5)]

# for total_users in random_total_users:
#     rank_counts = rank_counts_template.copy()
#     print(f"\nTotal users: {total_users}")
#     for i in range(1, total_users + 1):
#         rank = check_rank(i, total_users)
#         rank_counts[rank] += 1
#         # print(f"User {i}: {rank}")

#     # ﾗﾝｸごとの人数をﾌﾟﾘﾝﾄ
#     for rank, count in rank_counts.items():
#         print(f"{rank}: {count} users")

#     # 全体の合計数をﾌﾟﾘﾝﾄ
#     total_count = sum(rank_counts.values())
#     print(f"Ranked total users: {total_count} users")



# total_users = 277
# top_or_buttom_20_per = int((total_users / 100) * 20)
# top_80_per = total_users - top_or_buttom_20_per


# ranks = {
#     10: "A+ (Top 10%)",
#     20: "A (Top 10-20%)",
#     30: "B+ (Top 20-30%)",
#     40: "B (Mid 30-40%)",
#     50: "C+ (Mid 40-50%)",
#     60: "C (Mid 50-60%)",
#     70: "D+ (Lower 60-70%)",
#     80: "D (Lower 70-80%)",
#     90: "E (Bottom 80-90%)",
#     100: "F (Bottom 90-100%)"
# }

# txt = ""


# # top 20%
# for i in range(top_or_buttom_20_per):
#     if i >= (top_or_buttom_20_per // 2):
#         print(f"{i+1} {ranks[20]}")
#     else:
#         print(f"{i+1} {ranks[10]}")


# top_30_to_80 = total_users - (top_or_buttom_20_per)*2

# # Top 30% - 80%
# for i in range(0 + top_or_buttom_20_per, top_80_per):
#     if i < (top_30_to_80 // 6)* 3:
#         print(f"{i+1} {ranks[30]}")
#     elif i < (top_30_to_80 // 6) * 4:
#         print(f"{i+1} {ranks[40]}")
#     elif i < (top_30_to_80 // 6) * 5:
#         print(f"{i+1} {ranks[50]}")
#     elif i < (top_30_to_80 // 6) * 6:
#         print(f"{i+1} {ranks[60]}")
#     elif i < (top_30_to_80 // 6) * 7:
#         print(f"{i+1} {ranks[70]}")
#     else:
#         print(f"{i+1} {ranks[80]}")

# # Buttom 20%
# for i in range((total_users - top_or_buttom_20_per), total_users):
#     if i >= (total_users - (top_or_buttom_20_per // 2)):
#         print(f"{i+1} {ranks[100]}")
#     else:
#         print(f"{i+1} {ranks[90]}")









# def check_rank(number):
#     total_users = 277
#     buttom_20_per = int((total_users / 100) * 20)
#     top_80_per = total_users - buttom_20_per

#     ranks = {
#         10: "A+ (Top 10%)",
#         20: "A (Top 20%)",
#         30: "B+ (Top 30%)",
#         40: "B (Mid 40%)",
#         50: "C+ (Mid 50%)",
#         60: "C (Mid 60%)",
#         70: "D+ (Lower 70%)",
#         80: "D (Lower 80%)",
#         90: "E (Bottom 20%)",
#         100: "F (Bottom 10%)"
#     }





#     # Top 80%
#     if number < top_80_per:
#         if number < (top_80_per // 8):
#             return ranks[10]
#         elif number < (top_80_per // 8) * 2:
#             return ranks[20]
#         elif number < (top_80_per // 8) * 3:
#             return ranks[30]
#         elif number < (top_80_per // 8) * 4:
#             return ranks[40]
#         elif number < (top_80_per // 8) * 5:
#             return ranks[50]
#         elif number < (top_80_per // 8) * 6:
#             return ranks[60]
#         elif number < (top_80_per // 8) * 7:
#             return ranks[70]
#         else:
#             return ranks[80]

#     # Buttom 20%
#     else:
#         if number >= (total_users - (buttom_20_per // 2)):
#             return ranks[100]
#         else:
#             return ranks[90]

# # ﾃｽﾄ
# for i in range(1, 277+1):
#     print(f"{i} : {check_rank(i)}")





# total_users = 277
# top_or_buttom_20_per = int((total_users / 100) * 20)
# top_80_per = total_users - top_or_buttom_20_per


# ranks = {
#     10: "A+ (Top 10%)",
#     20: "A (Top 20%)",
#     30: "B+ (Top 30%)",
#     40: "B (Mid 40%)",
#     50: "C+ (Mid 50%)",
#     60: "C (Mid 60%)",
#     70: "D+ (Lower 70%)",
#     80: "D (Lower 80%)",
#     90: "E (Bottom 20%)",
#     100: "F (Bottom 10%)"
# }

# txt = ""


# # top 20%
# for i in range(top_or_buttom_20_per):
#     if i >= (top_or_buttom_20_per // 2):
#         print(f"{i+1} {ranks[20]}")
#     else:
#         print(f"{i+1} {ranks[10]}")


# # Top 80%
# for i in range(0, top_80_per):
#     if i < (top_80_per // 8):
#         print(f"{i+1} {ranks[10]}")
#     elif i < (top_80_per // 8) * 2:
#         print(f"{i+1} {ranks[20]}")
#     elif i < (top_80_per // 8) * 3:
#         print(f"{i+1} {ranks[30]}")
#     elif i < (top_80_per // 8) * 4:
#         print(f"{i+1} {ranks[40]}")
#     elif i < (top_80_per // 8) * 5:
#         print(f"{i+1} {ranks[50]}")
#     elif i < (top_80_per // 8) * 6:
#         print(f"{i+1} {ranks[60]}")
#     elif i < (top_80_per // 8) * 7:
#         print(f"{i+1} {ranks[70]}")
#     else:
#         print(f"{i+1} {ranks[80]}")

# # Buttom 20%
# for i in range((total_users - top_or_buttom_20_per), total_users):
#     if i >= (total_users - (top_or_buttom_20_per // 2)):
#         print(f"{i+1} {ranks[100]}")
#     else:
#         print(f"{i+1} {ranks[90]}")




# for i in range(total_rows):

#     if i < buttom_20_per:
#         print(f"Row {i + 1} is in the bottom 20%")
#     else: # top_80_per
#         print(f"Row {i + 1} is in the top 80%")


# for i in range(total_rows):
#     league_percentage_text = ""


#     for j in range(10):
#         if j * percentile_size <= i < (j + 1) * percentile_size:
#             new_number = 12 - j
#             league_percentage = (j + 1) * 10
#             if league_percentage == 90:
#                 league_percentage_text = f"Row: {i + 1}, Bottom: 10%"
#             elif league_percentage == 100:
#                 league_percentage_text = f"Row: {i + 1}, Bottom: 20%"
#             else:
#                 league_percentage_text = f"Row: {i + 1}, Top: {league_percentage}%"
#             break

#     print(league_percentage_text)
# print(buttom_20)





# import math

# total_rows = 58
# percentile_size =  math.ceil((total_rows / 100) * 10)
# threshold = int((total_rows / 100) * 20)
# buttom_20 = total_rows - threshold

# for i in range(total_rows):
#     league_percentage_text = ""
#     for j in range(10):
#         if j * percentile_size <= i < (j + 1) * percentile_size:
#             new_number = 12 - j
#             league_percentage = (j + 1) * 10
#             if league_percentage == 90:
#                 league_percentage_text = f"Row: {i + 1}, Bottom: 10%"
#             elif league_percentage == 100:
#                 league_percentage_text = f"Row: {i + 1}, Bottom: 20%"
#             else:
#                 league_percentage_text = f"Row: {i + 1}, Top: {league_percentage}%"
#             break

#     print(league_percentage_text)
# print(buttom_20)
