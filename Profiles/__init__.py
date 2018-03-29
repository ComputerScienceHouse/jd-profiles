import os
import requests
import subprocess
import csh_ldap 

import flask_migrate
from flask import Flask, render_template, jsonify, request, redirect, send_from_directory
from flask_pyoidc.flask_pyoidc import OIDCAuthentication
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import func


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
ldap = csh_ldap.CSHLDAP(app.config['LDAP_BIND_DN'], app.config['LDAP_BIND_PASS'])

from Profiles.utils import before_request, get_member_info
from Profiles.ldap import get_image, get_gravatar, ldap_get_active_members, ldap_get_all_members, ldap_get_member, ldap_search_members, ldap_is_active, ldap_get_eboard, _ldap_get_group_members


@app.route("/", methods=["GET"])
@auth.oidc_auth
@before_request
def home(info=None):
    return redirect("/profile/" + info["uid"],
                              code = 302)


@app.route("/members", methods=["GET"])
@auth.oidc_auth
@before_request
def members(info=None):
    return render_template("members.html", 
    						  info=info, 
    						  title = "Active Members",
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
def results(uid=None, info=None):
    if request.method == "POST":
    	searched = request.form['query']
    	return render_template("results.html", 
    						    info=info, 
    						    title = "Search Results: "+searched,
    						    members=ldap_search_members(searched))


@app.route("/search/<searched>", methods=["GET"])
@auth.oidc_auth
@before_request
def search(searched=None, info=None):
    return render_template("members.html", 
    						  info=info, 
    						  title = "Search Results: "+searched,
    						  members=ldap_search_members(searched))


@app.route("/group/<group>", methods=["GET"])
@auth.oidc_auth
@before_request
def group(group=None, info=None):
    if "eboard" in group:
    	return render_template("members.html", 
    						    info=info,
    						    title = "Group: " + group,
    						    members=ldap_get_eboard())
    else:
    	return render_template("members.html", 
    						    info=info, 
    						    title = "Group: " + group,
    						    members=_ldap_get_group_members(group))


@app.route("/edit", methods=["GET"])
@auth.oidc_auth
@before_request
def edit(uid=None, info=None):
    return render_template("edit.html", 
                                        info=info, 
                                        member_info=get_member_info(info['uid']))


@app.route("/update", methods=["POST"])
@auth.oidc_auth
@before_request
def update(uid=None, info=None):
    if request.method == "POST":
        return request.form


@app.route("/logout")
@auth.oidc_logout
def logout():
    return redirect("/", 302)


@app.route("/image/<uid>", methods=["GET"])
def image(uid):
    image = get_image(uid)
    if image: 
        return image
    else:
        return redirect(get_gravatar(uid), code=302)
