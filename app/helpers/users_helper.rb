module UsersHelper

    def format_date str
        if str.kind_of? Array
            str = str[0].split("-")[0]
        else
            str = str.split("-")[0]
        end
        year = str[0...4]
        month = str[6...8]
        day = str[4...6]
        return day + "/" + month + "/" + year
    end

    def format_attr attr
        return attr.gsub(/([a-z\d])([A-Z])/,'\1 \2').downcase
    end
end
