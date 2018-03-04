import os
import random
import string

# Flask config
DEBUG = True
IP = os.environ.get('SWAG_IP', '127.0.0.1')
PORT = os.environ.get('SWAG_PORT', 8080)
SERVER_NAME = os.environ.get('SWAG_SERVER_NAME', 'swag.csh.rit.edu')

# DB Info
SQLALCHEMY_DATABASE_URI = os.environ.get('SQLALCHEMY_DATABASE_URI', 'sqlite:///{}'.format(os.path.join(os.getcwd(), "data.db")))

# Openshift secret
SECRET_KEY = os.getenv("SECRET_KEY", default=''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(64)))

# OpenID Connect SSO config
OIDC_ISSUER = os.environ.get('SWAG_OIDC_ISSUER', 'https://sso.csh.rit.edu/auth/realms/csh')
OIDC_CLIENT_CONFIG = {
    'client_id': os.environ.get('SWAG_OIDC_CLIENT_ID', 'swag'),
    'client_secret': os.environ.get('SWAG_OIDC_CLIENT_SECRET', ''),
    'post_logout_redirect_uris': [os.environ.get('SWAG_OIDC_LOGOUT_REDIRECT_URI', 'https://swag.csh.rit.edu/logout')]
}