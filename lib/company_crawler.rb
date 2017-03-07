# encoding: UTF-8

require_relative "http_helper"
require "json"
require "time"
require_relative "models"
require_relative "utils"

module ThreeBan
  class CompanyCrawler
    NEEQ_HOST = "http://www.neeq.com.cn"
    
    def initialize()

    end

    def run
      start_time = Time.now
      httpclient = HTTPHelper.new(NEEQ_HOST)
      page = 0
      is_last_page = false
      while (!is_last_page)

        path = "/nqxxController/nqxx.do?page=#{page}&typejb=T&sortfield=xxzqdm&sorttype=asc"
        resp = httpclient.get(path)
        json_str = resp.body[5...-1]
        resp_json = JSON.parse(json_str)
        company_list = resp_json[0]["content"]
        company_list.each {|company|
          code = company["xxzqdm"]
          name = company["xxzqjc"].gsub(" ", "")
          trade_type = company["xxzrlx"]
          industry = company["xxhyzl"]
          location = company["xxssdq"]
          puts "#{code}, #{name}, #{trade_type}, #{industry}, #{location}"
          ::Companies.upsert({"code" => code}, 
            {"code" => code, "name" => name, "trade_type" => trade_type,
             "industry" => industry, "location" => location, "updated_at" => Time.now})
        }
        page += 1
        is_last_page = resp_json[0]["lastPage"]
      end
    end
  end

end

if __FILE__ == $0
  crawler = ThreeBan::CompanyCrawler.new
  crawler.run
end
