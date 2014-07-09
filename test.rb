require 'ldap'

conn = LDAP:SSLConn.new("ldap.csh.rit.edu", 636)
conn.sasl_bind('', '')
