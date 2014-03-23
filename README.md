profiles
========

This is the new CSH LDAP Profiles used by the Computer Science House (csh.rit.edu).

This gives a web interface to the LDAP servers that CSH uses to store all members'
information. It uses webauth to bind to the server as the viewing agent that way 
the system does not need any credentials to the backend LDAP server. Also thi
makes it so that users can only ever edit attributes that they have permission to.
Most of the pages are cachd for one hour to increase time. The only page that is
not cached is /user/:uid. The site also tries to use browser cache for most of the
images to prevent unneeded requests since they very rarely change.

File an issue if you find any problem.
