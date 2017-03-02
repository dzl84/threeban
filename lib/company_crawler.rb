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
      
      path = "/nqxxController/nqxx.do?page=0&typejb=T&sortfield=xxzqdm&sorttype=asc"
      resp = httpclient.get(path)
      json_str = resp.body[5...-1]
      resp_json = JSON.parse(json_str)
      company_list = resp_json[0]["content"]
      company_list.each {|company|
        code = company["xxzqdm"]
        name = company["xxzqjc"]
        trade_type = company["xxzrlx"]
        industry = company["xxhyzl"]
        location = company["xxssdq"]
        #::Companies.upsert
      }
      
      # ::TopUser.delete_all({"updated" => {"$lt" => start_time}})
    end

  end

end

if __FILE__ == $0
  crawler = ThreeBan::CompanyCrawler.new
  crawler.run
end
