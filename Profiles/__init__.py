import os

import csh_ldap
import flask_migrate
import requests
from flask import Flask, render_template, request, redirect
from flask_pyoidc.flask_pyoidc import OIDCAuthentication
from flask_sqlalchemy import SQLAlchemy
from flask_uploads import UploadSet, configure_uploads, IMAGES

app = Flask(__name__)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

# Get app config from absolute file path
if os.path.exists(os.path.join(os.getcwd(), "config.py")):
    app.config.from_pyfile(os.path.join(os.getcwd(), "config.py"))
else:
    app.config.from_pyfile(os.path.join(os.getcwd(), "config.env.py"))

auth = OIDCAuthentication(app, issuer=app.config["OIDC_ISSUER"],
                          client_registration_info=app.config["OIDC_CLIENT_CONFIG"])

# Database setup
db = SQLAlchemy(app)
migrate = flask_migrate.Migrate(app, db)

# Models


# Disable SSL certificate verification warning
requests.packages.urllib3.disable_warnings()

# LDAP
_ldap = csh_ldap.CSHLDAP(app.config['LDAP_BIND_DN'], app.config['LDAP_BIND_PASS'])

photos = UploadSet('photos', IMAGES)

app.config['UPLOADED_PHOTOS_DEST'] = 'static/img'
configure_uploads(app, photos)

# pylint: disable=wrong-import-position
from Profiles.utils import before_request, get_member_info, process_image
from Profiles.ldap import ldap_update_profile, get_image, get_gravatar, ldap_get_active_members, ldap_get_all_members, \
    ldap_get_member, ldap_search_members, ldap_is_active, ldap_get_eboard, _ldap_get_group_members


@app.route("/", methods=["GET"])
@auth.oidc_auth
@before_request
def home(info=None):
    return redirect("/profile/" + info["uid"],
                    code=302)


@app.route("/members", methods=["GET"])
@auth.oidc_auth
@before_request
def members(info=None):
    return render_template("members.html",
                           info=info,
                           title="Active Members",
                           members=ldap_get_active_members())


@app.route("/profile/<uid>", methods=["GET"])
@auth.oidc_auth
@before_request
def profile(uid=None, info=None):
    return render_template("profile.html",
                           info=info,
                           member_info=get_member_info(uid))


@app.route("/results", methods=["POST"])
@auth.oidc_auth
@before_request
def results(info=None):
    searched = request.form['query']
    return render_template("results.html",
                           info=info,
                           title="Search Results: " + searched,
                           members=ldap_search_members(searched))


@app.route("/search/<searched>", methods=["GET"])
@auth.oidc_auth
@before_request
def search(searched=None, info=None):
    # return jsonify(ldap_search_members(searched))
    return render_template("members.html",
                           info=info,
                           title="Search Results: " + searched,
                           members=ldap_search_members(searched))


@app.route("/group/<ldap_group>", methods=["GET"])
@auth.oidc_auth
@before_request
def group(ldap_group=None, info=None):
    if "eboard" in ldap_group:
        return render_template("members.html",
                               info=info,
                               title="Group: " + ldap_group,
                               members=ldap_get_eboard())
    return render_template("members.html",
                           info=info,
                           title="Group: " + ldap_group,
                           members=_ldap_get_group_members(ldap_group))


@app.route("/edit", methods=["GET"])
@auth.oidc_auth
@before_request
def edit(info=None):
    return render_template("edit.html",
                           info=info,
                           member_info=get_member_info(info['uid']))


@app.route("/update", methods=["POST"])
@auth.oidc_auth
@before_request
def update(info=None):
    if request.method == "POST" and 'photo' in request.files:
        return process_image(request.files['photo'], info['uid'])
    ldap_update_profile(request.form, info['uid'])
    return ""


@app.route('/upload', methods=['GET', 'POST'])
@auth.oidc_auth
@before_request
def upload(info=None):
    if request.method == 'POST' and 'photo' in request.files and process_image(request.files['photo'], info['uid']):
        return redirect('/', 302)
    return redirect('/', 302)


@app.route("/logout")
@auth.oidc_logout
def logout():
    return redirect("/", 302)


@app.route("/image/<uid>", methods=["GET"])
def image(uid):
    user_image = get_image(uid)
    if user_image:
        return user_image
    return redirect(get_gravatar(uid), code=302)
