# encoding: UTF-8

require_relative "http_helper"
require "json"
require "time"
require_relative "models"
require_relative "utils"
require "pdf-reader"
require "open-uri"

module ThreeBan
  class DisclosureCrawler
    NEEQ_HOST = "http://www.neeq.com.cn"
    
    def initialize()
    end

    def crawl_disclosure
      start_time = Time.now
      httpclient = HTTPHelper.new(NEEQ_HOST)
      start_date = get_last_date || Date.strptime("2010-01-01", "%Y-%m-%d")
      last_code = get_last_disclosure_code
      while start_date <= Date.today
        end_date_str = (start_date + 1).to_s
        start_date_str = start_date.to_s
        page = 0
        is_last_page = false
        is_done = false
        while (!is_last_page)
          puts "Getting #{start_date_str} - #{end_date_str}, page #{page}"
          path = "/disclosureInfoController/infoResult.do"
          data = "disclosureType=5&page=#{page}&companyCd=&isNewThree=1&startTime=#{start_date_str}&endTime=#{end_date_str}&keyword=&xxfcbj="
          resp = httpclient.post(path, data)
          json_str = resp.body[5...-1]
          resp_json = JSON.parse(json_str)
          disclosure_list = resp_json[0]["listInfo"]["content"]
          disclosure_list.each {|disclosure|
            if disclosure["disclosureCode"] == last_code
              is_done = true
              break
            end
            save_disclosure(disclosure)
          }
          break if is_done
          page += 1
          is_last_page = resp_json[0]["listInfo"]["lastPage"]
        end
        start_date = Date.strptime(end_date_str, "%Y-%m-%d")
      end
    end
    
    def crawl_disclosure_content
      disclosures = ::Disclosures.find({:content => {"$exists" => false}}, \
        {:sort => {:publishTime => 1}, :limit => 100})
      httpclient = HTTPHelper.new(NEEQ_HOST)
      disclosures.each {|disc|
        begin
          content = nil
          if disc[:filePath].end_with?(".pdf")
            io     = open("#{NEEQ_HOST}#{disc[:filePath]}")
            reader = PDF::Reader.new(io)
            content = ""
            reader.pages.each { |page|
              page.text.split("\n").each {|line|
                next if line.length == 0
                if line.start_with?(" ")
                  content += "\n#{line}"
                else
                  content += line 
                end
              }
            }
          elsif disc[:filePath].end_with?(".txt")
              resp = httpclient.get(disc[:filePath])
              if resp.code == '200'
                content = resp.body 
              else
                puts "Failed to get content for disclosure #{disc[:filePath]}, code: #{resp.code}"
                next
              end
          else
              puts "Unsupported suffix #{disc[:filePath]}"
              next
          end
          
          puts "Saving content for disclosureCode #{disc[:disclosureCode]} on #{disc[:publishTime]}"
          ::Disclosures.update({:disclosureCode => disc[:disclosureCode]}, {:content => content})
        rescue Exception => e
          puts "Failed to get content for disclosure #{disc[:filePath]}, #{e.class.name}"
          puts e.backtrace
          ::Disclosures.update({:disclosureCode => disc[:disclosureCode]}, {:content => "error"})
        end
      }
    end
    
    def get_last_date
      rec = ::Disclosures.last(nil, :sort => {:publishTime => 1})
      rec[:publishDate]
    end
    
    def get_last_disclosure_code
      rec = ::Disclosures.last(nil, :sort => {:publishTime => 1})
      rec[:disclosureCode]
    end
    
    def save_disclosure(disclosure)
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
        "Other-#{type}"
      end
      publishDate = disclosure["publishDate"]
      str = disclosure["upDate"]["time"]
      publishTime = Time.at(str.to_i/1000)
      ::Disclosures.upsert({:code => code, :disclosureCode => disclosureCode},
        {:code => code, :name => name, :filePath => filePath, 
         :disclosureCode => disclosureCode, :disclosureTitle => disclosureTitle,
         :disclosureType => disclosureType, :publishDate => publishDate,
         :publishTime => publishTime, :updated_at => Time.now}
      )
    end
  end
end

if __FILE__ == $0
  crawler = ThreeBan::DisclosureCrawler.new
  crawler.crawl_disclosure
  crawler.crawl_disclosure_content
end
