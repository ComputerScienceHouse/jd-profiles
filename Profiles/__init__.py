import os
import requests
import subprocess

import flask_migrate
from flask import Flask, render_template, jsonify, request, redirect, send_from_directory
from flask_optimize import FlaskOptimize
from flask_pyoidc.flask_pyoidc import OIDCAuthentication
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import func

from Profiles.utils import before_request

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


@app.route("/", methods=["GET"])
@auth.oidc_auth
@flask_optimize.optimize()
@before_request
def home(info=None):
    return render_template("index.html", info=info)


@app.route("/logout")
@auth.oidc_logout
def logout():
    return redirect("/", 302)


@app.route("/image/<uid>", methods=["GET"])
def image(uid):
    return redirect("https://profiles.csh.rit.edu/image/" + uid, code=302)
