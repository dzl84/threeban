module Parser
  class GenericParser
    def initialize(config_file = nil)
      @config = config_file
    end

    def parse_listedCompanies
      url = "http://www.neeq.com.cn/nqxxController/nqxx.do?page=0&typejb=T&xxzqdm=&xxzrlx=&xxhyzl=&xxssdq=&sortfield=xxzqdm&sorttype=asc"
    end
  end

  class ListedCompany

  end
end
