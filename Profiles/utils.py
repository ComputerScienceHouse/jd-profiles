# Credit to Liam Middlebrook and Ram Zallan
# https://github.com/liam-middlebrook/gallery
import subprocess

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
            "user_obj": user_obj
        }
        kwargs["info"] = info
        return func(*args, **kwargs)

    return wrapped_function

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


def ldap_is_financial_director(account):
    return _ldap_is_member_of_directorship(account, 'Financial')


def ldap_is_eval_director(account):
    return _ldap_is_member_of_directorship(account, 'Evaluations')


def ldap_is_current_student(account):
    return _ldap_is_member_of_group(account, 'current_student')


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