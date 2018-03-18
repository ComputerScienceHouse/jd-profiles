# Credit to Liam Middlebrook and Ram Zallan
# https://github.com/liam-middlebrook/gallery
import subprocess
import datetime

from flask import session
from functools import wraps
from Profiles import ldap


def before_request(func):
    @wraps(func)
    def wrapped_function(*args, **kwargs):
        git_revision = subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD']).decode('utf-8').rstrip()
        uuid = str(session["userinfo"].get("sub", ""))
        uid = str(session["userinfo"].get("preferred_username", ""))
        user_obj = ldap.get_member(uid, uid=True)
        info = {
            "git_revision": git_revision,
            "uuid": uuid,
            "uid": uid,
            "user_obj": user_obj,
            "member_info": get_member_info(uid)
        }
        kwargs["info"] = info
        return func(*args, **kwargs)

    return wrapped_function

def get_member_info(uid):
    account = ldap_get_member(uid)
    member_info = {
        "user_obj": account,
        "group_list": ldap_get_groups(account),
        "info_string": get_member_info_string(uid),
        "uid": account.uid,
        "ritUid": parse_rit_uid(account.ritDn),
        "name": account.gecos,
        "active": ldap_is_active(account),
        "onfloor": ldap_is_onfloor(account),
        "room": ldap_get_roomnumber(account),
        "hp": account.housingPoints,
        "plex": account.plex,
        "rn": ldap_get_roomnumber(account),
        "birthday": parse_date(account.birthday),
        "memberSince": parse_date(account.memberSince),
        "year": parse_account_year(account.memberSince)
    }
    return member_info


def _ldap_get_group_members(group):
    return ldap.get_group(group).get_members()


def _ldap_is_member_of_group(member, group):
    group_list = member.get("memberOf")
    for group_dn in group_list:
        if group == group_dn.split(",")[0][3:]:
            return True
    return False


def _ldap_add_member_to_group(account, group):
    if not _ldap_is_member_of_group(account, group):
        ldap.get_group(group).add_member(account, dn=False)


def _ldap_remove_member_from_group(account, group):
    if _ldap_is_member_of_group(account, group):
        ldap.get_group(group).del_member(account, dn=False)


def _ldap_is_member_of_directorship(account, directorship):
    directors = ldap.get_directorship_heads(directorship)
    for director in directors:
        if director.uid == account.uid:
            return True
    return False


#Getters 

def ldap_get_member(username):
    return ldap.get_member(username, uid=True)


def ldap_get_active_members():
    return _ldap_get_group_members("active")


def ldap_get_intro_members():
    return _ldap_get_group_members("intromembers")


def ldap_get_onfloor_members():
    return _ldap_get_group_members("onfloor")


def ldap_get_current_students():
    return _ldap_get_group_members("current_student")


def ldap_get_all_members():
    return _ldap_get_group_members("member")

def ldap_get_groups(account):
    group_list = account.get("memberOf")
    groups = []
    for group_dn in group_list:
        groups.append(group_dn.split(",")[0][3:])
    return groups

def ldap_get_eboard():
    members = []

    members.append(_ldap_get_group_members("eboard-chairman"))
    members.append(_ldap_get_group_members("eboard-evaluations"))
    members.append(_ldap_get_group_members("eboard-financial"))
    members.append(_ldap_get_group_members("eboard-history"))
    members.append(_ldap_get_group_members("eboard-imps"))
    members.append(_ldap_get_group_members("eboard-opcomm"))
    members.append(_ldap_get_group_members("eboard-research"))
    members.append(_ldap_get_group_members("eboard-secretary"))
    members.append(_ldap_get_group_members("eboard-social"))

    return members



# Status checkers

def ldap_is_active(account):
    return _ldap_is_member_of_group(account, 'active')


def ldap_is_alumni(account):
    # If the user is not active, they are an alumni.
    return not _ldap_is_member_of_group(account, 'active')


def ldap_is_eboard(account):
    return _ldap_is_member_of_group(account, 'eboard')


def ldap_is_rtp(account):
    return _ldap_is_member_of_group(account, 'rtp')


def ldap_is_intromember(account):
    return _ldap_is_member_of_group(account, 'intromembers')


def ldap_is_onfloor(account):
    return _ldap_is_member_of_group(account, 'onfloor')


def ldap_is_current_student(account):
    return _ldap_is_member_of_group(account, 'current_student')


# Directorships

def ldap_is_financial_director(account):
    return _ldap_is_member_of_directorship(account, 'financial')


def ldap_is_eval_director(account):
    return _ldap_is_member_of_directorship(account, 'evaluations')


def ldap_is_chairman(account):
    return _ldap_is_member_of_directorship(account, 'chairman')


def ldap_is_history(account):
    return _ldap_is_member_of_directorship(account, 'history')


def ldap_is_imps(account):
    return _ldap_is_member_of_directorship(account, 'imps')


def ldap_is_social(account):
    return _ldap_is_member_of_directorship(account, 'Social')


def ldap_is_rd(account):
    return _ldap_is_member_of_directorship(account, 'research')


# Setters

def ldap_set_housingpoints(account, housing_points):
    account.housingPoints = housing_points
    ldap_get_current_students.cache_clear()
    ldap_get_member.cache_clear()


def ldap_set_roomnumber(account, room_number):
    if room_number == "":
        room_number = None
    account.roomNumber = room_number
    ldap_get_current_students.cache_clear()
    ldap_get_member.cache_clear()


def ldap_set_active(account):
    _ldap_add_member_to_group(account, 'active')
    ldap_get_active_members.cache_clear()
    ldap_get_member.cache_clear()


def ldap_set_inactive(account):
    _ldap_remove_member_from_group(account, 'active')
    ldap_get_active_members.cache_clear()
    ldap_get_member.cache_clear()


def ldap_set_current_student(account):
    _ldap_add_member_to_group(account, 'current_student')
    ldap_get_current_students.cache_clear()
    ldap_get_member.cache_clear()


def ldap_set_non_current_student(account):
    _ldap_remove_member_from_group(account, 'current_student')
    ldap_get_current_students.cache_clear()
    ldap_get_member.cache_clear()


def ldap_get_roomnumber(account):
    try:
        return account.roomNumber
    except AttributeError:
        return ""

def get_member_info_string(uid):
    account = ldap_get_member(uid)
    member_info = ""
    if ldap_is_onfloor(account) and ldap_is_active(account):
        member_info+=("On Floor")
    if not ldap_is_onfloor(account) and ldap_is_active(account):
        member_info+=("Off Floor")
    if ldap_is_intromember(account):
        member_info+=(", Freshman")
    if ldap_is_eboard(account):
        member_info+=(", Eboard")
    if ldap_is_financial_director(account):
        member_info+=(", Financial")
    if ldap_is_eval_director(account):
        member_info+=(", Evals")
    if ldap_is_rtp(account):
        member_info+=(", RTP")
    if ldap_is_chairman(account):
        member_info+=(", Chairman")
    if ldap_is_history(account):
        member_info+=(", History")
    if ldap_is_imps(account):
        member_info+=(", House Improvements")
    # if ldap_is_social(account):
    #     member_info+=(", Social")
    if ldap_is_rd(account):
        member_info+=(", R&D")
    return member_info

def ldap_search_members(query):
    active = [account for account in ldap_get_all_members()]
    results = []
    query = query.lower()

    for account in active:
        uid = account.uid.lower()
        name = account.gecos

        if name:
            name = name.lower()
            if query in uid or query in name:
                results.append(account)

    return results

def parse_date(date):
    if(date):
        year = date[0:4]
        month = date[4:6]
        day = date[6:8]
        return month + "-" + day + "-" + year
    else:
        return False
   
def parse_rit_uid(dn):
    return dn.split(",")[0][4:]

def parse_account_year(date):
    year = int(date[0:4])
    month = int(date[4:6])
    if month <= 8:
        year = year - 1
    return year