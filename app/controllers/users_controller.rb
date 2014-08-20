require 'ldap'
require 'ldap/schema'
require 'will_paginate/array'

class UsersController < ApplicationController
    include CacheableCSRFTokenRails

    @@cache_time = 24.hours
    @@user_treebase = "ou=Users,dc=csh,dc=rit,dc=edu"
    @@group_treebase = "ou=Groups,dc=csh,dc=rit,dc=edu"
    @@committee_treebase = "ou=Committees,dc=csh,dc=rit,dc=edu"
    @@search_vars = Set.new ['cn', 'description', 'displayName', 'mail', 'nickName',
        'plex', 'sn', 'uid', 'mobile', 'twitterName', 'github']

    # Yo Man I heard you wanted some caching
    caches_action :list_years, expires_in: @@cache_time
    caches_action :list_groups, expires_in: @@cache_time
    caches_action :list_users, expires_in: @@cache_time, cache_path: Proc.new { |c| c.params }
    caches_action :group, expires_in: @@cache_time, cache_path: Proc.new { |c| c.params }
    caches_action :year, expires_in: @@cache_time, cache_path: Proc.new { |c| c.params }
    caches_action :image, expires_in: @@cache_time, cache_path: Proc.new { |c| c.params }
    caches_action :search, expires_in: @@cache_time, cache_path: Proc.new { |c| c.params['search'] }

    # Searches LDAP for users
    def search
        @users = []
        search_str = params[:search][:search]
        filter = "(|"
        @@search_vars.each { |var| filter << "(#{var}=*#{search_str}*)" }
        filter << ")"
        
        bind_ldap do |ldap_conn|
            ldap_conn.search(@@user_treebase,  LDAP::LDAP_SCOPE_SUBTREE, filter, 
                             ["uid", "cn", "memberSince"]) do |entry|
                @users << entry.to_hash   
            end
        end
        
        # if only one result is returned, redirect to that user
        if @users.length == 1
            redirect_to "/user/#{@users[0]["uid"][0]}"
        else
            @users.reverse!
            render 'list_users'
        end
    end
    
    # List all the users by newest members first
    def list_users
        @users = []
        params[:page] = "a" if params[:page] == nil
        attrs = ["uid", "cn", "memberSince"]
        bind_ldap do |ldap_conn|
            ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, 
                          "(uid=#{params[:page]}*)", attrs = attrs) do |entry|
                @users << entry.to_hash
            end
        end
        @users.sort! { |x,y| x["uid"] <=> y["uid"] }
        @title = "users"
        @current = params[:page]
        @url = "users"
    end
    
    # Lists all the groups sorted alphabetically
    def list_groups
        @groups = []
        bind_ldap do |ldap_conn|
            ldap_conn.search(@@group_treebase, LDAP::LDAP_SCOPE_SUBTREE, 
                              "(cn=*)") do |entry|
                @groups << entry.to_hash
            end
        end
        @title = "groups"
        @groups.sort! { |x,y| x["cn"] <=> y["cn"] }
    end

    # Lists all the years for members
    def list_years
        @years = Time.new.month >= 8 ? (1994..Time.new.year).to_a.reverse : (1994...Time.new.year).to_a.reverse
        @title = "years"
    end

    # Returns the jpegPhoto for the given uid. The user can specify the size of
    # the image to return as well
    def image
        response.headers["Expires"] = 10.minute.from_now.httpdate
        image = nil
        bind_ldap do |ldap_conn|
            ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, 
                              "(uid=#{params[:uid]})", ["jpegPhoto"]) do |entry|
                image = entry["jpegPhoto"][0] if entry["jpegPhoto"] != nil && entry["jpegPhoto"][0].length > 0
            end
        end
        if image
            begin
                image = MiniMagick::Image.read(image)
            rescue
                image = MiniMagick::Image.open('app/assets/images/blank_user.png')
            end
        else
            image = MiniMagick::Image.open('app/assets/images/blank_user.png')
        end
        if params[:size] != nil && params[:size].to_i > 0
            image.resize "#{params[:size]}x#{params[:size]}"
        end
        send_data(image.to_blob, filename: "#{params[:uid]}.jpg", type: "image/jpeg")
    end
    
    def autocomplete
        @users = []
        bind_ldap do |ldap_conn|
            ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE,
                             "(|(uid=*#{params[:term]}*)(cn=*#{params[:term]}*)
                             (mail=*#{params[:term]}*)(nickName=*#{params[:term]}*))",
                             ["uid", "cn"]) do |entry|
                @users << entry.to_hash["uid"][0]
            end
        end
        render :json => @users[0..10]
    end

    def me
        @uid = ENV['WEBAUTH_USER']
        bind_ldap do |ldap_conn|
            ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, "(uid=#{@uid})") do |entry|
                @user = format_fields entry.to_hash
                get_attrs(@user["objectClass"], ldap_conn).each do |attr|
                    @user[attr[0]] = (@user[attr[0]] == nil) ? [nil, attr[1]] : [@user[attr[0]], attr[1]]
                end
                @title = @uid
                @user = @user.except("uidNumber", "homeDirectory",
                                 "diskQuotaSoft", "diskQuotaHard", 
                                 "gidNumber", "objectClass", "uid", "ou",
                                 "userPassword", "l", "o", 
                                 "conditional", "gecos")
            end
            
            @groups = get_groups(ldap_conn, @user["dn"][0])           
            @positions = get_positions(ldap_conn, @user["dn"][0])
                
            @status = "Active - off-floor"
            if @user["alumni"] == [["1"], :single]
                @status = "Alumni"
            elsif @user["onfloor"] == [["1"], :single]
                @status = "Active - on-floor"
            end
        end
        render 'me'
    end

    # Displays all the information for the given user
    def user 
        redirect_to :me if ENV['WEBAUTH_USER'] == params[:uid]
        @user = nil
        bind_ldap do |ldap_conn|
            ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, "(uid=#{params[:uid]})") do |entry|
                @user = format_fields entry.to_hash.except(
                    "objectClass", "uidNumber", "homeDirectory",
                    "diskQuotaSoft", "diskQuotaHard", "gidNumber")
            end
            if @user == nil
                redirect_to root_path
            else
                @title = @user["uid"][0]
                @groups = get_groups(ldap_conn, @user["dn"][0])           
                @positions = get_positions(ldap_conn, @user["dn"][0])
                
                @status = "Active - off-floor"
                if @user["alumni"] == ["1"]
                    @status = "Alumni"
                elsif @user["onfloor"] == ["1"]
                    @status = "Active - on-floor"
                end
            end
        end
    end

    # Updates the given user's attributes
    def update 
        attr_key = nil
        image_upload = false
        attr_value = []
        real_input = []
        
        if params['picture'] != nil
            attr_key = 'jpegPhoto'
            image_upload = true
            image = MiniMagick::Image.read(params[:picture])
            max = [image[:width].to_f, image[:height].to_f].max
            if max > 1024
                height = image[:height].to_f / (max / 1024)
                width = image[:width].to_f / (max / 1024)
                image.resize("#{height.to_i}x#{width.to_i}")
                update = LDAP.mod(LDAP::LDAP_MOD_REPLACE | LDAP::LDAP_MOD_BVALUES, 
                              attr_key, [image.to_blob])
            else
                update = LDAP.mod(LDAP::LDAP_MOD_REPLACE | LDAP::LDAP_MOD_BVALUES, 
                              attr_key, [params[:picture].read])
            end
        else
            params.except("controller", "action", "utf8").each do |key, value|
                attr_key = key.split("_")[0]
                if attr_key == "birthday"
                    begin
                        attr_value << value.to_datetime.strftime('%Y%m%d%H%M%S-0400') if value != ""
                        real_input << value if value != ""
                    rescue Exception
                        attr_value << "BAD"
                    end
                else
                    attr_value << value if value != ""
                    real_input << value if value != ""
                end
            end
            update = LDAP.mod(LDAP::LDAP_MOD_REPLACE, attr_key, attr_value)
        end
        
        result = {"key" => attr_key}
        dn = "uid=#{request.headers['WEBAUTH_USER']},#{@@user_treebase}"
        bind_ldap do |ldap_conn|
            begin
                result["single"] = is_single attr_key, ldap_conn
                ldap_conn.modify(dn, [update])
                result["success"] = true
                result["value"] = real_input if real_input != nil
                expire_cache(ldap_conn, dn, image_upload, attr_key)
            rescue LDAP::Error => e
                Rails.logger.error "Error modifying ldap for #{request.headers['WEBAUTH_USER']}, #{e}"
                result["success"] = false
                ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, 
                                  "(uid=#{request.headers['WEBAUTH_USER']})", [attr_key]) do |entry|
                    user = format_fields entry.to_hash
                    result["value"] = user[attr_key] != nil ? user[attr_key] : ""
                    if (attr_key == "birthday" || attr_key == "memberSince") && result["value"][0] != nil
                        result["value"] = [DateTime.parse(result["value"][0]).strftime('%m/%d/%Y')]
                    end
                end
            end
        end
        
        # uploading images refreshes the screen while everything else is ajax / js 
        if image_upload
            redirect_to :me
        else
            render text: "var status = '#{result.to_s.gsub(/=>/, ":")}';"
        end
    end

    # Gets all the users for the given group
    def group
        params[:page] = "a" if params[:page] == nil
        @users = []
        filter = "(cn=#{params[:group]})"
        bind_ldap do |ldap_conn|
            ldap_conn.search(@@group_treebase, LDAP::LDAP_SCOPE_SUBTREE, filter) do |entry|
                @users = entry.to_hash["member"].to_a
                @title = entry.to_hash["cn"][0]
            end
            @users = [] if @users == [""]
        
            filter = "(|"
            if @users.length > 100
                @current = params[:page]
                @url = "group/#{params[:group]}"
                @users.each do |dn| 
                    if dn.split(",")[0].split("=")[1][0] == params[:page]
                        filter += "(uid=#{dn.split(",")[0].split("=")[1]})"
                    end
                end
            else
                @users.each { |dn| filter += "(uid=#{dn.split(",")[0].split("=")[1]})" }
            end
            filter += ")"
            @users = []
            ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, filter, 
                             ["uid", "cn", "memberSince"]) do |entry|
                @users << entry.to_hash
            end
            @users.sort! { |x,y| x["uid"] <=> y["uid"] }
        end
        render 'list_users'
    end

    # Gets all the user for each school year. Aug - May
    def year
        @users = []
        year = params[:year].to_i
        attrs = ["uid", "cn", "memberSince"]
        filter  = "(&(memberSince>=#{year}0801010101-0400)(memberSince<=#{year + 1}0801010101-0400))"
        bind_ldap do |ldap_conn|
            ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, filter, attrs) do |entry|
                @users << entry.to_hash
            end
        end
        @users.reverse!
        @title = "#{params[:year]} - #{params[:year].to_i + 1}"
        render 'list_users'
    end

    def clear_cache
        Rails.cache.clear
        redirect_to root_path
    end

    private
        
        def format_fields map
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
            start_time = Time.now.to_f * 1000
            ENV['KRB5CCNAME'] = request.env['KRB5CCNAME']
            ldap_conn = LDAP::Conn.new(host = Global.ldap.host)
            ldap_conn.set_option( LDAP::LDAP_OPT_PROTOCOL_VERSION, 3 ) 
            ldap_conn.sasl_bind('', '')
            yield ldap_conn
            ldap_conn.unbind()
            end_time = Time.now.to_f * 1000
            Rails.logger.info "LDAP time: #{(end_time - start_time).round(2)} ms"
        end

        # deals with expiring all the needed cache when an update happens. Only the
        # affected cache is expired
        def expire_cache ldap_conn, dn, image_upload, attr_key
            if image_upload
                expire_action action: :image, uid: request.headers['WEBAUTH_USER']
            elsif attr_key == 'cn'
                expire_action action: :list_users, page: request.headers['WEBAUTH_USER'][0]
                get_groups(ldap_conn, dn).each do |cn|
                    expire_action action: :group, group: cn
                    expire_action action: :group, group: cn, page: request.headers['WEBAUTH_USER'][0]
                end
                expire_action action: :year, year: get_year(ldap_conn, request.headers['WEBAUTH_USER'])
            elsif @@search_vars.include? attr_key
                expire_action action: :search
            end 
        end

        # Gets the positions that the user holds and caches the result. 
        # get_groups must be called first
        def get_positions(ldap_conn, dn)
            Rails.cache.fetch("positions-#{dn}", expires_in: @@cache_time) do
                Rails.logger.info "Getting positions for #{dn}"
                positions = []
                ldap_conn.search(@@committee_treebase, LDAP::LDAP_SCOPE_SUBTREE, "(head=#{dn})") do |entry|
                    positions << "#{entry.to_hash['cn'][0]} Director"
                end
                positions << "RTP" if @groups.include? "rtp"
                positions << "Drink Admin" if @groups.include? "drink"
                positions
            end
        end

        # Gets the groups that the given user is a part of and caches them
        def get_groups(ldap_conn, dn)
            Rails.cache.fetch("groups-#{dn}", expires_in: @@cache_time) do
                Rails.logger.info "Getting groups for #{dn}"
                groups = []
                ldap_conn.search(@@group_treebase, LDAP::LDAP_SCOPE_SUBTREE, "(member=#{dn})") do |entry|
                    groups << entry.to_hash["cn"][0]
                end
                groups
            end
        end
        
        # Gets the year that the person is from. This is used in clearing the 
        # cache for the given year
        def get_year(ldap_conn, uid)
            Rails.cache.fetch("member-since-#{uid}", expires_in: @@cache_time) do
                Rails.logger.info "Getting year for #{uid}"
                member_since = nil
                ldap_conn.search(@@user_treebase, LDAP::LDAP_SCOPE_SUBTREE, "(uid=#{uid})", ["memberSince"]) do |entry|
                    member_since = entry.to_hash['memberSince']
                end
                year = member_since[0][0..3] if member_since != nil && member_since.length >= 1
                year 
            end
        end


        # Gets the attributes that the given user can have along with info
        # on if there can be multiple of the value
        # object_classes - the object classes that the user belongs to, used
        #   to get the values allowed
        def get_attrs(object_classes, ldap_conn)
            Rails.cache.fetch("object-classes-#{object_classes}", expires_in: @@cache_time) do
                Rails.logger.info "Getting attributes for #{object_classes}"
                schema = ldap_conn.schema()
                attr_set = Set.new
                real_attrs = []

                object_classes.each do |oc|
                    if oc == "person"
                        schema.must(oc).each { |attr| attr_set.add attr }
                    elsif oc == "posixAccount"
                        schema.must(oc).each { |attr| attr_set.add attr }
                        schema.may(oc).each { |attr| attr_set.add attr }
                    elsif oc == "drinkUser"
                        schema.must(oc).each { |attr| attr_set.add attr }
                    elsif oc == "ibuttonUser"
                        schema.may(oc).each { |attr| attr_set.add attr }
                    elsif oc == "profiledMember"
                        schema.may(oc).each { |attr| attr_set.add attr }
                    elsif oc == "houseMember"
                        schema.may(oc).each { |attr| attr_set.add attr }
                    elsif oc == "ritStudent"
                        schema.must(oc).each { |attr| attr_set.add attr }
                        schema.may(oc).each { |attr| attr_set.add attr }
                    elsif oc == "inetOrgPerson"
                        schema.may(oc).each { |attr| attr_set.add attr }
                    end
                end
                schema["attributeTypes"].each do |s|
                    name = s.split(" ")[3][1..-2]
                    # deals with when attributes have aliases
                    n = s.split("NAME")[1].split("DESC")[0].strip
                    name = n.split("'")[1] if n[0] == "("
                    
                    if attr_set.include? name.strip
                        if s.split(" ")[-2] == "SINGLE-VALUE"
                            real_attrs << [name, :single]
                        else
                            real_attrs << [name, :multiple]
                        end
                    end
                end
                real_attrs
            end
        end

        def is_single (attr, ldap_conn)
            Rails.cache.fetch("is-single-#{attr}", expires_in: @@cache_time) do
                Rails.logger.info "Getting single status for #{attr}"
                result = false
                schema = ldap_conn.schema()
                schema["attributeTypes"].each do |s|
                    name = s.split(" ")[3][1..-2]
                    # deals with when attributes have aliases
                    n = s.split("NAME")[1].split("DESC")[0].strip
                    name = n.split("'")[1] if n[0] == "("
                    result = s.split(" ")[-2] == "SINGLE-VALUE" if name == attr
                end
                result
            end
        end
end
