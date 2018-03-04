# Credit to Liam Middlebrook and Ram Zallan
# https://github.com/liam-middlebrook/gallery
import subprocess

from flask import session
from functools import wraps


def before_request(func):
    @wraps(func)
    def wrapped_function(*args, **kwargs):
        git_revision = subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD']).decode('utf-8').rstrip()
        uuid = str(session["userinfo"].get("sub", ""))
        uid = str(session["userinfo"].get("preferred_username", ""))
        info = {
            "git_revision": git_revision,
            "uuid": uuid,
            "uid": uid
        }
        kwargs["info"] = info
        return func(*args, **kwargs)

    return wrapped_function
