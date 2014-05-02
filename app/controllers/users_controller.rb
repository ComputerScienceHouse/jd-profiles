require 'ldap'
require 'ldap/schema'
require 'will_paginate/array'

class UsersController < ApplicationController
    include CacheableCSRFTokenRails
    caches_action :list_users, :expires_in => 5.hour, :cache_path => Proc.new { |c| c.params }
    caches_action :list_years, :expires_in => 5.hour
    caches_action :list_groups, :expires_in => 5.hour
    caches_action :group, :expires_in => 5.hour, :cache_path => Proc.new { |c| c.params }
    caches_action :year, :expires_in => 5.hour, :cache_path => Proc.new { |c| c.params }
    caches_action :image, :expires_in => 5.hour, :cache_path => Proc.new { |c| c.params }
    caches_action :user, :expires_in => 5.hour, :cache_path => Proc.new { |c| c.params }
    caches_action :search, :expires_in => 5.hour, :cache_path => Proc.new { |c| c.params }
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
        bind_ldap
        @ldap_conn.search(@@user_treebase,  LDAP::LDAP_SCOPE_SUBTREE, filter, attrs = attrs) do |entry|
            @users << entry.to_hash   
        end
        unbind_ldap
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
        params[:page] = "a" if params[:page] == nil
        attrs = ["uid", "cn", "memberSince"]
        bind_ldap
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, "(uid=#{params[:page]}*)", attrs = attrs) do |entry|
            @users << entry.to_hash
        end
        unbind_ldap
        @users.sort! { |x,y| x["uid"] <=> y["uid"] }
        @title = "users"
        @current = params[:page]
        @url = "users"
    end
    
    # Lists all the groups sorted alphabetically
    def list_groups
        @groups = []
        bind_ldap
        @ldap_conn.search(@@group_treebase, LDAP::LDAP_SCOPE_SUBTREE, "(cn=*)") do |entry|
            @groups << entry.to_hash
        end
        @title = "groups"
        unbind_ldap
        @groups.sort! { |x,y| x["cn"] <=> y["cn"] }
    end

    # Lists all the years for members
    def list_years
        if Time.new.month >= 8
            @years = (1994..Time.new.year).to_a.reverse
        else
            @years = (1994...Time.new.year).to_a.reverse
        end
        @title = "years"
    end

    def image
        response.headers["Expires"] = 10.minute.from_now.httpdate
        bind_ldap
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, 
                          "(uid=#{params[:uid]})") do |entry|
            if entry["jpegPhoto"] != nil && entry["jpegPhoto"] != [""]
                send_data entry["jpegPhoto"][0], :filename => "#{params[:uid]}", 
                    :type => 'image/png',:disposition => 'inline'
            else
                data = File.open("app/assets/images/blank_user.png").read
                send_data(data , :filename => "#{params[:uid]}.png", :type=>'image/png')
            end
        end
        unbind_ldap
    end
    
    def autocomplete
        @users = []
        bind_ldap
        attrs = ["uid", "cn"]
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE,
                         "(|(uid=*#{params[:term]}*)(cn=*#{params[:term]}*))",
                         attrs = attrs) do |entry|
            @users << entry.to_hash["uid"][0]
        end
        if @users.length > 10
            render :json => @users[1..10]
        else
            render :json => @users
        end
    end

    # Displays all the information for the given user
    def user 
        bind_ldap
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, 
                          "(uid=#{params[:uid]})") do |entry|
            @user = format_fields entry.to_hash.except("objectClass", "uidNumber", "homeDirectory",
                                         "diskQuotaSoft", "diskQuotaHard", 
                                         "gidNumber")
            @title = entry.to_hash["uid"][0]

        end
        @groups = []
        Rails.logger.info @user["dn"]
        @ldap_conn.search(@@group_treebase, LDAP::LDAP_SCOPE_SUBTREE,
                        "(member=#{@user["dn"][0]})") do |entry|
            @groups << entry.to_hash["cn"][0]
        end
        unbind_ldap
        @allow_edit = params[:uid] == request.headers['WEBAUTH_USER']
    end

    # shows the edit page for the user
    def edit
        bind_ldap
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, 
                        "(uid=#{request.headers['WEBAUTH_USER']})") do |entry|
            @user = format_fields entry.to_hash
            get_attrs(@user["objectClass"]).each do |attr|
                if @user[attr[0]] == nil
                    @user[attr[0]] = [[""], attr[1]]
                else
                    @user[attr[0]] = [@user[attr[0]], attr[1]]
                end
            end
            @title = @user["uid"][0][0]
            @user = @user.except("uidNumber", "homeDirectory",
                                 "diskQuotaSoft", "diskQuotaHard", 
                                 "gidNumber", "memberSince", 
                                 "objectClass", "uid", "ou", "userPassword", 
                                 "l", "o", "conditional")
        end
        unbind_ldap
    end

    # Updates the given user's attributes
    def update
        updates = []
        map = {}
        expire_action :action => :image, :uid => request.headers['WEBAUTH_USER']
        expire_action :action => :user, :uid => request.headers['WEBAUTH_USER']
        expire_action :action => :search
        
        if params[:photo] != nil
            image = MiniMagick::Image.read(params[:photo])
            image.resize("300x300") if image[:width] > 300 || image[:height] > 300
            updates << LDAP.mod(LDAP::LDAP_MOD_REPLACE | LDAP::LDAP_MOD_BVALUES, 
                                "jpegPhoto", [image.to_blob])
        else
            params[:field].each do |key, value|
                splits = key.split("_")
                type = splits[0]
                key = splits[splits.length - 1]
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
        bind_ldap
        begin
            @ldap_conn.modify("uid=#{request.headers['WEBAUTH_USER']},#{@@user_treebase}", updates)
            result = {status: "ok", message: "Updated your attributes", attribute: params[:field]}
        rescue
            result = {status: "error", message: "could not update attribute", attribute: params[:field]}
        end
        unbind_ldap
        respond_to do |format|
            format.html do 
                if result[:status] == "ok"
                    flash[:succes] = "Updated your attributes :)"
                else
                    flash[:error] = "Could not update attributes :("
                end
                redirect_to "/user/#{request.headers['WEBAUTH_USER']}" 
            end
            format.json { render :json => result }
        end
    end

    # Gets all the users for the give group
    def group
        params[:page] = "a" if params[:page] == nil
        @users = []
        attrs = ["uid", "cn", "memberSince"]
        filter = "(cn=#{params[:group]})"
        bind_ldap
        @ldap_conn.search(@@group_treebase, LDAP::LDAP_SCOPE_SUBTREE, filter) do |entry|
            @users = entry.to_hash["member"].to_a
            @title = entry.to_hash["cn"][0]
        end
        @users = [] if @users == [""]
        
        filter = "(|"
        if @users.length > 100
            @current = params[:page]
            @url = "group/#{params[:group]}"
            @users.each { |dn| filter += "(uid=#{dn.split(",")[0].split("=")[1]})" if dn.split(",")[0].split("=")[1][0] == params[:page] }
        else
            @users.each { |dn| filter += "(uid=#{dn.split(",")[0].split("=")[1]})" }
        end
        filter += ")"
        @users = []
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, filter, attrs = attrs) do |entry|
            @users << entry.to_hash
        end
        @users.sort! { |x,y| x["uid"] <=> y["uid"] }
        unbind_ldap
        render 'list_users'
    end

    # Gets all the user for each school year. Aug - May
    def year
        @users = []
        year = params[:year].to_i
        attrs = ["uid", "cn", "memberSince"]
        filter  = "(&(memberSince>=#{year}0801010101-0400)(memberSince<=#{year + 1}0801010101-0400))"
        bind_ldap
        @ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, filter, 
                        attrs = attrs) do |entry|
            @users << entry.to_hash
        end
        unbind_ldap
        @users.reverse!
        @title = "#{params[:year]} - #{params[:year].to_i + 1}"
        render 'list_users'
    end

    private
        
        def format_fields map
            Rails.logger.info map
            new_map = Hash.new
            new_map["uid"] = map["uid"] if map.key? "uid"
            new_map["cn"] = map["cn"] if map.key? "cn"
            new_map["mail"] = map["mail"] if map.key? "mail"
            new_map["mobile"] = map["mobile"] if map.key? "mobile"
            new_map["drinkBalance"] = map["drinkBalance"] if map.key? "drinkBlance"
            new_map["birthday"] = map["birthday"] if map.key? "birthday"
            new_map["housingPoints"] = map["housingPoints"] if map.key? "housingPoints"
            new_map["sn"] = map["sn"] if map.key? "sn"
            new_map["homepageURL"] = map["homepageURL"] if map.key? "homepageURL"
            new_map["blogURL"] = map["blogURL"] if map.key? "blogURL"
            map.each do |key, value| 
                new_map[key] = value if !new_map.key? key
            end

            return new_map
        end
    
        # Gets the ldap connection for the given user using the kerberos auth
        # provided by webauth
        def bind_ldap
            ENV['KRB5CCNAME'] = request.env['KRB5CCNAME']
            @ldap_conn = LDAP::SSLConn.new(
                host = Global.ldap.host, 
                port = Global.ldap.port)
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
                a = schema.must(oc)
                a.each { |attr| attr_set.add(attr) } if a != nil

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
            real_attrs << ["dn", :single]
            return real_attrs
        end
end
