import os
import requests
import subprocess
import csh_ldap 

import flask_migrate
from flask import Flask, render_template, jsonify, request, redirect, send_from_directory
from flask_optimize import FlaskOptimize
from flask_pyoidc.flask_pyoidc import OIDCAuthentication
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import func


app = Flask(__name__)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

flask_optimize = FlaskOptimize()

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

from Profiles.utils import before_request
from Profiles.utils import ldap_get_active_members
from Profiles.utils import ldap_get_all_members
from Profiles.utils import ldap_get_member
from Profiles.utils import ldap_search_members
from Profiles.utils import ldap_is_active
from Profiles.utils import ldap_get_eboard
from Profiles.utils import get_member_info
from Profiles.utils import _ldap_get_group_members

@app.route("/", methods=["GET"])
@auth.oidc_auth
@flask_optimize.optimize()
@before_request
def home(info=None):
    return render_template("profile.html", 
    						  info=info, 
    						  profile=ldap_get_member(info["uid"]), 
    						  member_info=info["member_info"], 
    						  editable=True)

@app.route("/members", methods=["GET"])
@auth.oidc_auth
@flask_optimize.optimize()
@before_request
def members(info=None):
    return render_template("members.html", 
    						  info=info, 
    						  title = "Active Members",
    						  members=ldap_get_active_members())

@app.route("/profile/<uid>", methods=["GET"])
@auth.oidc_auth
@flask_optimize.optimize()
@before_request
def profile(uid=None, info=None):
    return render_template("profile.html", 
    						  info=info, 
    						  member_info=get_member_info(uid),
    						  editable = False)

@app.route("/results", methods=["POST"])
@auth.oidc_auth
@flask_optimize.optimize()
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
@flask_optimize.optimize()
@before_request
def search(searched=None, info=None):
    return render_template("members.html", 
    						  info=info, 
    						  title = "Search Results: "+searched,
    						  members=ldap_search_members(searched))

@app.route("/group/<group>", methods=["GET"])
@auth.oidc_auth
@flask_optimize.optimize()
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

@app.route("/logout")
@auth.oidc_logout
def logout():
    return redirect("/", 302)


@app.route("/image/<uid>", methods=["GET"])
def image(uid):
    return redirect("https://profiles.csh.rit.edu/image/" + uid, code=302)
