module UsersHelper
    def format_date str
        year = str[0...4]
        month = str[6...8]
        day = str[4...6]
        return day + "/" + month + "/" + year
    end
end
