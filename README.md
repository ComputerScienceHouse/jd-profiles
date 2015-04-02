CSH Profiles
========

The Computer Science House @ RIT's web interface to our LDAP server containing
all of our members' data. Users are able to view other users information that
they have access to, modify their own data, and search through all user

Authentication happens by taking the webauth kerberos token and authenticating
as the user who is viewing the page. This makes it show that they can only 
view / modify attributes that they have access to.

It is also able to be used as a easy way to access member's profile pictures.
A default profile picture will be returned if the user has not set one yet.
You can specify the size of the picture, if you do not then the default image
size will be returned.

```html
<img src="https://profiles.csh.rit.edu/image/:uid">
```

The server uses heavy caching to speed up the results as much as possible.
All you need to do to use the cache is to correctly set-up the environment
configuration file
