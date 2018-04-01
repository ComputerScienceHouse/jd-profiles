import os
import random
import string
from os import environ as env

# Flask config
DEBUG = True
IP = os.environ.get('PROFILES_IP', 'localhost')
PORT = os.environ.get('PROFILES_PORT', 8080)
SERVER_NAME = os.environ.get('PROFILES_SERVER_NAME', 'profiles.csh.rit.edu')

# DB Info
SQLALCHEMY_DATABASE_URI = os.environ.get('SQLALCHEMY_DATABASE_URI', 'sqlite:///{}'.format(os.path.join(os.getcwd(), "data.db")))

# Openshift secret
SECRET_KEY = os.getenv("SECRET_KEY", default=''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(64)))

# OpenID Connect SSO config
OIDC_ISSUER = os.environ.get('PROFILES_OIDC_ISSUER', 'https://sso.csh.rit.edu/auth/realms/csh')
OIDC_CLIENT_CONFIG = {
    'client_id': os.environ.get('PROFILES_OIDC_CLIENT_ID', 'profiles'),
    'client_secret': os.environ.get('PROFILES_OIDC_CLIENT_SECRET', ''),
    'post_logout_redirect_uris': [os.environ.get('PROFILES_OIDC_LOGOUT_REDIRECT_URI', 'https://profiles.csh.rit.edu/logout')]
}

LDAP_BIND_DN = env.get("LDAP_BIND_DN", default="cn=profiles,ou=Apps,dc=csh,dc=rit,dc=edu")
LDAP_BIND_PASS = env.get("LDAP_BIND_PW", default=None)