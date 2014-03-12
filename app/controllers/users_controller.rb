require 'net-ldap'
require 'ldap'

class UsersController < ApplicationController
    before_action :log
    @@user_treebase="ou=Users,dc=csh,dc=rit,dc=edu"
    @@group_treebase="ou=Groups,dc=csh,dc=rit,dc=edu"

    def search
        @users = []
        search_str = params[:search][:search]
        filter = "(|(cn=*#{search_str}*)(description=*#{search_str}*)" + 
                "(displayName=*#{search_str}*)(mail=*#{search_str}*)" + 
                "(nickname=*#{search_str}*)(plex=*#{search_str}*)" + 
                "(sn=*#{search_str}*)(uid=*#{search_str}*)(mobile=#{search_str}))"
        attrs = ["uid", "cn", "mail", "memberSince"]
        conn = get_conn
        conn.search(@@user_treebase,  LDAP::LDAP_SCOPE_SUBTREE, filter, 
                        attrs = attrs) do |entry|
            @users << entry.to_hash   
        end
        conn.unbind
        @users.reverse!
        render 'list_users'
    end

    def me
        redirect_to "/user/#{request.headers['WEBAUTH_USER']}"
    end

    def list_users
        @users = []
        attrs = ["uid", "cn", "mail", "memberSince"]
        conn = get_conn
        conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, "(uid=*)", 
                        attrs = attrs) do |entry|
            @users << entry.to_hash
        end
        @users.reverse!
        conn.unbind
    end

    def list_groups
        @groups = []
        conn = get_conn
        conn.search(@@group_treebase, LDAP::LDAP_SCOPE_SUBTREE, "(cn=*)",
                       attrs = attrs) do |entry|
            @groups << entry.to_hash
        end
        @groups.sort! { |x,y| x["cn"] <=> y["cn"] }
        conn.unbind
    end

    def list_years
        @years = []
        (1994...Time.new.year).to_a.reverse.each { |year| @years << year }
    end

    def user
        @user = []
        conn = get_conn
        conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, "(uid=#{params[:uid]})") do |entry|
            @user = entry.to_hash.except("objectClass", "uidNumber", "homeDirectory",
                                         "diskQuotaSoft", "diskQuotaHard", "jpegPhoto")
        end
        conn.unbind
    end

    def edit
        @user = []
        conn = get_conn
        conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, 
                        "(uid=#{request.headers['WEBAUTH_USER']})") do |entry|
             @user = entry.to_hash.except("objectClass", "uidNumber", "homeDirectory",
                                          "diskQuotaSoft", "diskQuotaHard", "jpegPhoto")
        end
        conn.unbind
    end

    def update
        updates = []
        params[:fields].each do |key, value|
            updates << LDAP.mod(LDAP::LDAP_MOD_REPLACE, key, [value])
        end
        conn = get_conn
        conn.modify("uid=#{request.headers['WEBAUTH_USER']},#{@@user_treebase}", 
                       updates)
        conn.unbind 
    end

    def group
        @users = []
        attrs = ["uid", "cn", "mail", "membersince"]
        filter = "(cn=#{params[:group]})"
        conn = get_conn
        conn.search(@@group_treebase, LDAP::LDAP_SCOPE_SUBTREE, filter) do |entry|
            @users = entry.to_hash["member"].to_a
        end
        filter = "(|"
        @users.each { |dn| filter += "(uid=#{dn.split(",")[0].split("=")[1]})" }
        filter += ")"
        Rails.logger.debug filter
        @users = []
        get_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, filter, 
                        attrs = attrs) do |entry|
            @users << entry.to_hash
        end
        @users.reverse!
        conn.unbind 

        Rails.logger.debug @users
        render 'list_users'
    end

    def year
        @users = []
        year = params[:year].to_i
        Rails.logger.debug year
        attrs = ["uid", "cn", "mail", "memberSince"]
        filter  = "(&(memberSince>=#{year}0801010101-0400)(memberSince<=#{year + 1}0801010101-0400))"
        conn = get_conn
        conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, filter, 
                        attrs = attrs) do |entry|
            @users << entry.to_hash
        end
        conn.unbind
        @users.reverse!
        render 'list_users'
    end

    private
        def log
            Log.create(user: request.headers['WEBAUTH_USER'], 
                       page: request.fullpath).save
        end

        def get_conn
            ENV['KRB5CCNAME'] = request.env['KRB5CCNAME']
            conn = LDAP::SSLConn.new(host = Global.ldap.host, port = Global.ldap.port)
            conn.sasl_bind('', '')
            return conn
        end
end
