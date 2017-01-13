# encoding: UTF-8

require_relative "http_helper"
require "nokogiri"
require "json"
require "time"
require_relative "models"
require_relative "broker"
require_relative "utils"

module Parser
  class TopUserParser
    def initialize(config_file = nil)
      @deals = {}
      @broker = Broker.new
      @run_times_after_trading_close = 1
    end


    def parse_TopUser
      start_time = Time.now
      httpclient = HTTPHelper.new("http://moniapi.eastmoney.com")
      path = "/webapi/json.aspx?type=get_zhuhe_rank&rankType=8607&recIdx=0&recCnt=100"
      resp = httpclient.get(path)
      respJSON = JSON.parse(resp.body)
      topZuhe = respJSON["data"]
      topZuhe.each {|zuhe|
        if zuhe["winCntRate"].to_f >= 0.95
          ::TopUser.delete_all({"zjzh" => zuhe["zjzh"]})
          zuhe["updated"] = Time.now
          zuhe["active"] = true
          ::TopUser.create!(zuhe)
          puts "Inserted zuhe: #{zuhe["zjzh"]}"

        end
      }
      ::TopUser.delete_all({"updated" => {"$lt" => start_time}})
    end

    def monitor_TopUser
      active_zuhe = ::TopUser.find({"active" => true})
      while true do
        begin
          puts "#{Time.now}: not in trading hours, sleep 60s..." && sleep(60) \
            if is_trading_time?
          if after_trading_time?
            if @run_times_after_trading_close > 0
              @run_times_after_trading_close = @run_times_after_trading_close -1
            else
              break
            end
          end
          puts "#{Time.now}: checking top users..."
          active_zuhe.cursor.rewind!()
          active_zuhe.each {|zuhe|
            parse_user(zuhe["zjzh"])
            sleep(5)
          }
          sleep(30)
        rescue Exception => e
          puts e.message
          puts e.backtrace
        end
      end
      puts "#{Time.now}: after trading hours, exiting..."
    end



    def parse_user(id)
      httpclient = HTTPHelper.new("http://moniapi.eastmoney.com")
      path = "/webapi/json.aspx?type=deals_all&zh=#{id}&recIdx=0&recCnt=15"


      begin
        resp = httpclient.get(path)

        respJSON = JSON.parse(resp.body)
        puts respJSON["message"] unless respJSON["message"] == ""
        deals = respJSON["data"]
        deals.each {|deal|
          if Date.today.to_s == deal["cjrq"]


            usrDeals = @deals[id]
            next if usrDeals and usrDeals.any? {|d| d["cjsj"] == deal["cjsj"]}
            puts deal
            unless usrDeals
              usrDeals = []
              @deals[id] = usrDeals
            end
            usrDeals << deal
            deal["topuser"] = id
            if deal["mmbz"] == "买入"
              @broker.buy(deal)
            else
              @broker.sell(deal)
            end
          else
            break
          end
        }
      rescue Exception => e
        puts "Failed to parse user #{id}. #{e.message}"
        puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
      end
    end

    def show_result
      @broker.show_result
    end

  end

end

if __FILE__ == $0
  # u = {"name" => "test"}
  # ::TopUser.create!(u)
  parser = Parser::TopUserParser.new
  parser.parse_TopUser
  parser.monitor_TopUser
  parser.show_result
  # (1..100).each {
  #   puts Time.now
  #   parser.parse_user("")
  #   sleep(60)
  # }
end
