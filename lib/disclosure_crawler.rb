# encoding: UTF-8

require_relative "http_helper"
require "json"
require "time"
require_relative "models"
require_relative "utils"

module ThreeBan
  class DisclosureCrawler
    NEEQ_HOST = "http://www.neeq.com.cn"
    
    def initialize()

    end

    def run
      start_time = Time.now
      httpclient = HTTPHelper.new(NEEQ_HOST)
      page = 0
      is_last_page = false
      while (!is_last_page)

        path = "/disclosureInfoController/infoResult.do"
        data = "disclosureType=5&page=0&companyCd=&isNewThree=1&startTime=2017-02-10&endTime=2017-03-12&keyword=&xxfcbj="
        resp = httpclient.post(path, data)
        json_str = resp.body[5...-1]
        resp_json = JSON.parse(json_str)
        disclosure_list = resp_json[0]["listInfo"]["content"]
        puts disclosure_list.size
        disclosure_list.each {|disclosure|
          code = disclosure["companyCd"]
          name = disclosure["companyName"].gsub(" ", "")
          filePath = disclosure["destFilePath"]
          disclosureCode = disclosure["disclosureCode"]
          disclosureTitle = disclosure["disclosureTitle"]
          type = disclosure["disclosureType"]
          disclosureType = case type
          when "9504"
            "临时公告"
          when "9503"
            "定期报告"
          when "9505"
            "中介机构公告"
          when "9510"
            "首次信息披露"
          else
            raise "Unknow disclosure type: #{type}"
          end
          publishDate = disclosure["publicDate"]
          str = disclosure["upDate"]["time"]
          publishTime = Time.at(str.to_i/1000)
          ::Disclosures.upsert({:code => code, :disclosureCode => disclosureCode},
            {:code => code, :name => name, :filePath => filePath, 
             :disclosureCode => disclosureCode, :disclosureTitle => disclosureTitle,
             :disclosureType => disclosureType}
            
          )
          
          # ::Companies.upsert({"code" => code}, 
            # {"code" => code, "name" => name, "trade_type" => trade_type,
             # "industry" => industry, "location" => location, 
             # "layer" => layer, "updated_at" => Time.now})
        }
        page += 1
        break
        is_last_page = resp_json[0]["lastPage"]
      end
    end
  end

end

if __FILE__ == $0
  crawler = ThreeBan::DisclosureCrawler.new
  crawler.run
end
