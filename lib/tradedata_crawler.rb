# encoding: UTF-8

require_relative "http_helper"
require "json"
require "time"
require_relative "models"
require_relative "utils"

module ThreeBan
  class TradeDataCrawler
    NEEQ_HOST = "http://www.neeq.com.cn"
    
    def initialize()

    end

    def run
      httpclient = HTTPHelper.new(NEEQ_HOST)
      page = 0
      is_last_page = false
      while (!is_last_page)

        path = "/nqhqController/nqhq.do?page=#{page}&type=G&sortfield=hqzqdm&sorttype=asc"
        resp = httpclient.get(path)
        json_str = resp.body[5...-1]
        resp_json = JSON.parse(json_str)
        tradedata_list = resp_json[0]["content"]
        tradedata_list.each {|data|
          code = data["hqzqdm"]
          name = data["hqzqjc"].gsub(" ", "")
          date = data["hqjsrq"]
          buy1 = data["hqbjw1"]
          buy1_amount = data["hqbsl1"]
          sell1 = data["hqsjw1"]
          sell1_amount = data["hqssl1"]
          total_deal = data["hqcjje"]
          total_amount = data["hqcjsl"]
          has_trade = (total_deal > 0) ? true : false
          next unless has_trade
          puts "Saving trade data for #{code}"
          ::TradeData.upsert({"code" => code, "date" => date}, 
            {"code" => code, "name" => name, "date" => date,
             "buy1" => buy1, "buy1_amount" => buy1_amount, 
             "sell1" => sell1, "sell1_amount" => sell1_amount,
             "total_deal" => total_deal, "total_amount" => total_amount,
             "updated_at" => Time.now})
        }
        page += 1
        is_last_page = resp_json[0]["lastPage"]
      end
    end
  end

end

if __FILE__ == $0
  crawler = ThreeBan::TradeDataCrawler.new
  crawler.run
end
