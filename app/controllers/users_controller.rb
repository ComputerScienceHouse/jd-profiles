require 'ldap'
require 'ldap/schema'

class UsersController < ApplicationController
    caches_page :list_users, :expires_in => 5.hour
    caches_page :list_years, :expires_in => 5.hour
    caches_page :list_groups, :expires_in => 5.hour
    caches_page :group, :expires_in => 5.hour, :cache_path => Proc.new { |c| c.request_url }
    caches_page :year, :expires_in => 5.hour
    caches_action :image, :expires_in => 5.hour, :cache_path => Proc.new { |c| c.params }
    before_action :log_before
    after_action :log_after
    before_action :bind_ldap, except: [:list_years, :me]
    after_action :unbind_ldap, except: [:list_years, :me]
    @@user_treebase="ou=Users,dc=csh,dc=rit,dc=edu"
    @@group_treebase="ou=Groups,dc=csh,dc=rit,dc=edu"

    # Searches LDAP for users
    def search
        @users = []
        search_str = params[:search][:search]
        filter = "(|(cn=*#{search_str}*)(description=*#{search_str}*)" + 
                "(displayName=*#{search_str}*)(mail=*#{search_str}*)" + 
                "(nickName=*#{search_str}*)(plex=*#{search_str}*)" + 
                "(sn=*#{search_str}*)(uid=*#{search_str}*)" + 
                "(mobile=#{search_str})(twitterName=#{search_str})" + 
                "(github=#{search_str}))"
        attrs = ["uid", "cn", "memberSince"]
        @ldap_conn.search(@@user_treebase,  LDAP::LDAP_SCOPE_SUBTREE, filter, 
                        attrs = attrs) do |entry|
            @users << entry.to_hash   
        end
        # if only one result is returned, redirect to that user
        if @users.length == 1
            redirect_to "/user/#{@users[0]["uid"][0]}"
        else
            @users.reverse!
            render 'list_users'
        end
    end

    # Shows the current user's page
    def me
        redirect_to "/user/#{request.headers['WEBAUTH_USER']}"
    end

    # List all the users by newest members first
    def list_users
        @users = []
        attrs = ["uid", "cn", "memberSince"]
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, "(uid=*)", 
                        attrs = attrs) do |entry|
            @users << entry.to_hash
        end
        @users.reverse!
    end
    
    # Lists all the groups sorted alphabetically
    def list_groups
        @groups = []
        @ldap_conn.search(@@group_treebase, LDAP::LDAP_SCOPE_SUBTREE, "(cn=*)") do |entry|
            @groups << entry.to_hash
        end
        @groups.sort! { |x,y| x["cn"] <=> y["cn"] }
    end

    # Lists all the years for members
    def list_years
        if Time.new.month >= 8
            @years = (1994..Time.new.year).to_a.reverse
        else
            @years = (1994...Time.new.year).to_a.reverse
        end
    end

    def image
        Rails.logger.debug "image called#{params[:uid]}"
        Rails.logger.debug "-------------------------------"
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, 
                          "(uid=#{params[:uid]})") do |entry|
            if entry["jpegPhoto"] != nil && entry["jpegPhoto"] != [""]
                send_data entry["jpegPhoto"][0], :filename => "#{params[:uid]}.jpg", 
                    :type => 'image/png',:disposition => 'inline'
            else
                data = File.open("app/assets/images/blank_user.png").read
                send_data(data , :filename => "#{params[:uid]}.png", :type=>'image/png')
            end
        end
    end

    # Displays all the information for the given user
    def user 
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, 
                          "(uid=#{params[:uid]})") do |entry|
            @user = entry.to_hash.except("objectClass", "uidNumber", "homeDirectory",
                                         "diskQuotaSoft", "diskQuotaHard", 
                                         "gidNumber")
        end
        @allow_edit = params[:uid] == request.headers['WEBAUTH_USER']
    end

    # shows the edit page for the user
    def edit
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, 
                        "(uid=#{request.headers['WEBAUTH_USER']})") do |entry|
            @user = entry.to_hash
            get_attrs(@user["objectClass"]).each do |attr|
                if @user[attr[0]] == nil
                    @user[attr[0]] = [[""], attr[1]]
                else
                    @user[attr[0]] = [@user[attr[0]], attr[1]]
                end
            end
            @user = @user.except("uidNumber", "homeDirectory",
                                 "diskQuotaSoft", "diskQuotaHard", 
                                 "gidNumber", "memberSince", 
                                 "objectClass", "uid", "ou", "userPassword", 
                                 "l", "o", "conditional")
        end
    end

    # Updates the given user's attributes
    def update
        updates = []
        map = {}
        if params[:photo] != nil
            uploaded_io = params[:photo]
        else
            params[:fields].each do |key, value|
                splits = key.split(":")
                type = splits[0]
                key = splits[1]
                if key == "birthday"
                    date = value.split("/")
                    date[0] = "0#{date[0]}" if date[0].length == 1
                    date[1] = "0#{date[1]}" if date[1].length == 1
                    value = "#{date[2]}#{date[0]}#{date[1]}010101-0400"
                end
                if map[key] == nil
                    if value == ""
                        map[key] = []
                    else
                        map[key] = [value]
                    end
                elsif value != ""
                    map[key] << value
                end
            end
        end
        map.each do |key, value|
            if value == []
                updates << LDAP.mod(LDAP::LDAP_MOD_DELETE, key, [])
            else
                updates << LDAP.mod(LDAP::LDAP_MOD_REPLACE, key, value)
            end
        end
        begin
            @ldap_conn.modify("uid=#{request.headers['WEBAUTH_USER']},#{@@user_treebase}", updates)
            flash[:succes] = "Updated your attributes :)"
        rescue
            flash[:error] = "Could not update attributes :("
        end
        redirect_to "/user/#{request.headers['WEBAUTH_USER']}"
    end

    # Gets all the users for the give group
    def group
        Rails.logger.debug "PAGE: " + params[:group]
        Rails.logger.debug "----------------------------"
        @users = []
        attrs = ["uid", "cn", "memberSince"]
        filter = "(cn=#{params[:group]})"
        @ldap_conn.search(@@group_treebase, LDAP::LDAP_SCOPE_SUBTREE, filter) do |entry|
            @users = entry.to_hash["member"].to_a
        end
        filter = "(|"
        @users.each { |dn| filter += "(uid=#{dn.split(",")[0].split("=")[1]})" }
        filter += ")"
        @users = []
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, filter, 
                        attrs = attrs) do |entry|
            @users << entry.to_hash
        end
        @users.reverse!

        render 'list_users'
    end

    # Gets all the user for each school year. Aug - May
    def year
        Rails.logger.debug "YEAR: " + params[:year]
        Rails.logger.debug "---------------------------"
        @users = []
        year = params[:year].to_i
        attrs = ["uid", "cn", "memberSince"]
        filter  = "(&(memberSince>=#{year}0801010101-0400)(memberSince<=#{year + 1}0801010101-0400))"
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, filter, 
                        attrs = attrs) do |entry|
            @users << entry.to_hash
        end
        @users.reverse!
        render 'list_users'
    end

    private
        def log_before
            @start_time = Time.now.to_f * 1000
        end
        # Logs the response time for each page
        def log_after
            Log.create(user: request.headers['WEBAUTH_USER'], 
                       page: request.fullpath, 
                       time: Time.now.to_f * 1000 - @start_time).save
        end

        # Gets the ldap connection for the given user using the kerberos auth
        # provided by webauth
        def bind_ldap
            Rails.logger.debug "=========================bind to ldap"
            ENV['KRB5CCNAME'] = request.env['KRB5CCNAME']
            @ldap_conn = LDAP::SSLConn.new(host = Global.ldap.host, port = Global.ldap.port)
            @ldap_conn.sasl_bind('', '')
        end

        # Unbinds the ldap connection
        def unbind_ldap
            @ldap_conn.unbind()
        end

        # Gets the attributes that the given user can have along with info
        # on if there can be multiple of the value
        # object_classes - the object classes that the user belongs to, used
        #   to get the values allowed
        def get_attrs object_classes
            schema = @ldap_conn.schema()
            attr_set = Set.new
            real_attrs = []
            object_classes.each do |oc|
                a = schema.may(oc)
                a.each { |attr| attr_set.add(attr) } if a != nil
            end
            schema["attributeTypes"].each do |s|
                name = s.split(" ")[3][1..-2]
                # deals with when attributes have aliases
                n = s.split("NAME")[1].split("DESC")[0].strip
                name = n.split("'")[1] if n[0] == "("
                if attr_set.include? name
                    if s.split(" ")[-2] == "SINGLE-VALUE"
                        real_attrs << [name, :single]
                    else
                        real_attrs << [name, :multiple]
                    end
                end
            end
            return real_attrs
        end
end
