# encoding: UTF-8

require_relative "http_helper"
require_relative "models/disclosure"
require_relative "utils"
require "json"
require "time"
require "pdf-reader"
require "open-uri"
require "concurrent"
require "trollop"

module ThreeBan
  class DisclosureCrawler
    NEEQ_HOST = "http://www.neeq.com.cn"
    DATA_ROOT = "/data"
    def initialize()
    end

    def crawl_disclosure
      start_time = Time.now
      httpclient = HTTPHelper.new(NEEQ_HOST)
      start_date = get_last_date || Date.strptime("2010-01-01", "%Y-%m-%d")
      last_code = get_last_disclosure_code
      while start_date <= Date.today
        start_date_str = start_date.to_s
        page = 0
        is_last_page = false
        is_done = false
        disclosures = []
        while (!is_last_page)
          
          path = "/disclosureInfoController/infoResult.do"
          data = "disclosureType=5&page=#{page}&companyCd=&isNewThree=1&startTime=#{start_date_str}&endTime=#{start_date_str}&keyword=&xxfcbj="
          resp = httpclient.post(path, data)
          json_str = resp.body[5...-1]
          resp_json = JSON.parse(json_str)
          disclosure_list = resp_json[0]["listInfo"]["content"]
          puts "Getting disclosures on #{start_date_str}, page #{page}, item #{disclosure_list.size}"
          disclosure_list.each {|disclosure|
            if last_code == disclosure["disclosureCode"]
              is_done = true
              is_last_page = true
              break
            end
            disclosures << parse_disc_json(disclosure)
          }
          next if is_done
          page += 1
          is_last_page = resp_json[0]["listInfo"]["lastPage"]
        end
        # Saving data into db in a batch
        Disclosure.create(disclosures) if disclosures.size > 0
        start_date = start_date + 1
      end
    end

    def crawl_disclosure_content
      disclosures = Disclosure.where(:filePath => nil).asc(:publishTime).limit(100)
      httpclient = HTTPHelper.new(NEEQ_HOST)
      count = 5
      pool = Concurrent::FixedThreadPool.new(count)
      disclosures.each {|disc|
        pool.post {
          puts "Downloading #{disc[:disclosureCode]} #{disc[:publishTime]} #{disc[:disclosureTitle]}"
          path = download_disclosure(disc)
          disc.update_attributes!(:filePath => path, :isDownloaded => true) unless path.nil?
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

    # Parse disclosure json to a hash for inserting into db
    def parse_disc_json(disclosure)
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
      
      {
        :code => code, :name => name, :fileURL => fileURL, 
        :disclosureCode => disclosureCode, :disclosureTitle => disclosureTitle,
        :disclosureType => disclosureType, :publishDate => publishDate,
        :publishTime => publishTime
      }
    end

    # Download the disclosure file and save it to disk
    def download_disclosure(disc)
      code = disc[:code]
      url = NEEQ_HOST + disc[:fileURL]
      filename = disc[:fileURL].split("/").last
      
      folder_path = DATA_ROOT + "/" + code.split("").join("/")
      file_path = folder_path + "/" + filename
      begin
        FileUtils.mkdir_p(folder_path)
        open(file_path, "w") do |file|
          file << open(url).read
        end
        return file_path
      rescue Exception => e
        puts e.backtrace 
      end
      return nil
    end
  end
end

if __FILE__ == $0
  ACTIONS = ["crawl-list", "download", "parse-content"]
  opts = Trollop::options do
    opt :action, "Actions to perform in the crawler", 
      :type => :string
  end
  unless ACTIONS.include?(opts[:action])
    raise "#{opts[:action]} is not a supported action. Available actions are #{ACTIONS}"
  end
  crawler = ThreeBan::DisclosureCrawler.new
  case opts[:action]
  when "crawl-list"
    crawler.crawl_disclosure
  when "download"
    crawler.crawl_disclosure_content
  when "parse-content"
  end
end
