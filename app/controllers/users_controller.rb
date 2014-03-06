require 'net-ldap'

class UsersController < ApplicationController
    @@user_treebase="ou=Users,dc=csh,dc=rit,dc=edu"
    @@group_treebase="ou=Groups,dc=csh,dc=rit,dc=edu"

    def search
        @users = []
        search_str = params[:search][:search]
        filter = "(|(cn=*#{search_str}*)(description=*#{search_str}*)" + 
                "(displayName=*#{search_str}*)(Email=*#{search_str}*)" + 
                "(nickname=*#{search_str}*)(plex=*#{search_str}*)" + 
                "(sn=*#{search_str}*)(uid=*#{search_str}*))"
        get_conn.open do |ldap|
            @users = ldap.search(base: @@user_treebase, filter: filter)
        end
        #@users = @users.sort_by { |entity| entity[:membersince] }.reverse
        @users.sort! { |x, y| y[:membersince] <=> x[:membersince] } 
        render 'list_users'
    end

    def me
        #uid = request.headers['WEBAUTH_USER']
        filter = Net::LDAP::Filter.eq("uid", "jd")
        attrs = ["uid", "cn", "givenname", "sn", "gecos", "mail", "displayname", 
                 "active", "nickname", "github", "birthday", "plex", "cn", 
                 "roomnumber", "housingpoints", "drinkbalance"]
        get_conn.open do |ldap|
            @user = ldap.search(base: @@user_treebase, filter: filter, attributes: attrs)[0]
        end
        render 'user'
    end

    def list_users
        @users = []
        attrs = ["uid", "cn", "mail"]
        get_conn.open do |ldap|
            @users = ldap.search(base: @@user_treebase)
        end
        @users.sort! { |x, y| y[:membersince] <=> x[:membersince] } 
    end

    def list_groups
        @groups = []
        get_conn.open do |ldap|
            @groups = ldap.search(base: @@group_treebase)
        end
    end

    def list_years
        @years = (1994..Time.new.year).to_a.reverse
    end

    def user
        @user = []
        filter = Net::LDAP::Filter.eq("uid", params[:uid])
        attrs = ["uid", "cn", "givenname", "sn", "gecos", "mail", "displayname", 
                 "active", "nickname", "github", "birthday", "plex", "cn", 
                 "roomnumber", "housingpoints", "drinkbalance"]
        get_conn.open do |ldap|
            @user = ldap.search(base: @@user_treebase, filter: filter, attributes: attrs)[0]
        end
    end

    def group
        @users = []
        attrs = ["uid", "cn", "mail", "membersince"]
        filter = Net::LDAP::Filter.eq("cn", params[:group])
        get_conn.open do |ldap|
            @users = ldap.search(base: @@group_treebase, filter: filter)[0][:member]
            filter = "(|"
            @users.each { |dn| filter += "(uid=#{dn.split(",")[0].split("=")[1]})" }
            filter += ")"
            @users = ldap.search(base: @@user_treebase, filter: filter, attributes: attrs)
        end
        @users.sort! { |x, y| y[:membersince] <=> x[:membersince] } 
        render 'list_users'
    end

    def year
        year = params[:year].to_i
        gt = Net::LDAP::Filter.ge("membersince", "#{year}0101000000-0400")
        lt = Net::LDAP::Filter.le("membersince", "#{year + 1}0101000000-0400")
        filter = Net::LDAP::Filter.join(gt, lt)
        #filter = Net::LDAP::Filter.eq("uid", "jd")
        puts filter
        get_conn.open do |ldap|
            @users = ldap.search(base: @@user_treebase, filter: filter)
        end
        @users.sort! { |x, y| y[:membersince] <=> x[:membersince] } 
        render 'list_users'
    end

    private
        def get_conn
            return Net::LDAP.new host: Global.ldap.host,
                port: Global.ldap.port,
                encryption: :simple_tls,
                auth: {
                    method: :simple,
                    username: Global.ldap.username,
                    password: Global.ldap.password
                }
        end
end
