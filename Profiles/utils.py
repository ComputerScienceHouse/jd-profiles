# Credit to Liam Middlebrook and Ram Zallan
# https://github.com/liam-middlebrook/gallery
import subprocess
import datetime
import imghdr
import ldap
import io


from flask import session
from functools import wraps
from functools import lru_cache
from Profiles import _ldap
from Profiles.ldap import *
from PIL import Image
from resizeimage import resizeimage


def before_request(func):
    @wraps(func)
    def wrapped_function(*args, **kwargs):
        git_revision = subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD']).decode('utf-8').rstrip()
        uuid = str(session["userinfo"].get("sub", ""))
        uid = str(session["userinfo"].get("preferred_username", ""))
        user_obj = _ldap.get_member(uid, uid=True)
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

    if ldap_is_active(account):
        alumInfo = None
    else:
        alumInfo = parse_alum_name(account.gecos)

    member_info = {
        "user_obj": account,
        "group_list": ldap_get_groups(account),
        "info_string": get_member_info_string(uid),
        "uid": account.uid,
        "ritUid": parse_rit_uid(account.ritDn),
        "name": account.cn,
        "alumInfo": alumInfo,
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


def parse_date(date):
    if(date):
        year = date[0:4]
        month = date[4:6]
        day = date[6:8]
        return month + "-" + day + "-" + year
    else:
        return False
   

def parse_rit_uid(dn):
    if dn:
        return dn.split(",")[0][4:]
    else:
        return None


def parse_account_year(date):
    if date:
        year = int(date[0:4])
        month = int(date[4:6])
        if month <= 8:
            year = year - 1
        return year
    else:
        return None


def parse_alum_name(gecos):
    return gecos.split(",")


def process_image(photo, uid):
    if imghdr.what(photo):
        key = 'jpegPhoto'
        account = ldap_get_member(uid)
        image = Image.open(photo)
        icon = resizeimage.resize_contain(image, [300, 300])
        icon = icon.convert("RGB")
        bin_icon = io.BytesIO()
        icon.save(bin_icon, format='JPEG') 

        con = _ldap.get_con()

        exists = account.jpegPhoto

        if not exists:
            ldap_mod = ldap.MOD_ADD
        else:
            ldap_mod = ldap.MOD_REPLACE

        mod = (ldap_mod, key, bin_icon.getvalue())

        mod_attrs = [mod]

        con.modify_s(account.get_dn(), mod_attrs)

        return True
    else:
        return False
