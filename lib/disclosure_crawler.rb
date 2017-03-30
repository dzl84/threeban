# encoding: UTF-8

require_relative "http_helper"
require "json"
require "time"

require_relative "models/disclosure"
require_relative "utils"
require "pdf-reader"
require "open-uri"
require "concurrent"

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
      disclosures = Disclosure.where({:content => {"$exists" => false}}, \
      {:sort => {:publishTime => 1}, :limit => 20})
      httpclient = HTTPHelper.new(NEEQ_HOST)
      count = 3
      pool = Concurrent::FixedThreadPool.new(count)
      disclosures.each {|disc|
        pool.post {
          save_disclosure_content(disc)
        }
      }
      pool.shutdown
      pool.wait_for_termination
    end

    def get_last_date
      rec = Disclosure.order_by(:publishTime => 'desc').first
      rec.publishDate rescue nil
    end

    def get_last_disclosure_code
      rec = Disclosure.order_by(:publishTime => 'desc').first
      rec.disclosureCode rescue nil
    end

    def save_disclosure_content(disc)
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
          return
          end
        else
          puts "Unsupported suffix #{disc[:filePath]}"
        return
        end

        puts "Saving content for disclosureCode #{disc[:disclosureCode]} on #{disc[:publishTime]}"
        ::Disclosure.update({:disclosureCode => disc[:disclosureCode]}, {:content => content, :hasContent => true})
      rescue Exception => e
        puts "Failed to get content for disclosure #{disc[:filePath]}, #{e.class.name}"
        puts e.backtrace
        Disclosure.update({:disclosureCode => disc[:disclosureCode]}, {:content => "error", :hasContent => true})
      end
    end

    def save_disclosure(disclosure)
      code = disclosure["companyCd"]
      name = disclosure["companyName"].gsub(" ", "")
      fileURL = disclosure["destFilePath"]
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
      Disclosure.create(
        :code => code, :name => name, :fileURL => fileURL,
        :disclosureCode => disclosureCode, :disclosureTitle => disclosureTitle,
        :disclosureType => disclosureType, :publishDate => publishDate,
        :publishTime => publishTime
      )
    end

    def download_disclosure(code, url)
      filename = url.split("/").last
      data_root = "/data"
      folder_path = data_root + "/" + code.split("").join("/")
      file_path = folder_path + "/" + filename
      begin
        FileUtils.mkdir_p(folder_path)
        open(file_path, "w") do |file|
          file << open(url).read
        end
        file_path
      rescue Exception => e
        puts e.backtrace 
      end
    end
  end
end

if __FILE__ == $0
  crawler = ThreeBan::DisclosureCrawler.new
  puts "Start: #{Time.now}"
  crawler.crawl_disclosure
  #crawler.crawl_disclosure_content
  puts "End: #{Time.now}"

end
