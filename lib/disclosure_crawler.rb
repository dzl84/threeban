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
      start_date = get_last_date || Date.strptime("2011-01-01", "%Y-%m-%d")
      days_to_crawl = 5
      while start_date <= Date.today and days_to_crawl >= 0
        days_to_crawl -= 1
        start_date_str = start_date.to_s
        last_codes = get_disclosureCodes_on(start_date_str)
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
            if last_codes.include?(disclosure["disclosureCode"])
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
      disclosures = Disclosure.where(:filePath => nil).asc(:publishTime).limit(500)
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
      rec = Disclosure.order_by(:publishDate => 'desc').first
      rec.publishDate rescue nil
    end

    def get_disclosureCodes_on(date)
      rec = Disclosure.where(:publishDate => date)
      rec.map{|disc| disc[:disclosureCode]}
    end

    def parse_disclosure_content(disc)
      begin
        puts "Saving content for disclosureCode #{disc[:disclosureCode]} on #{disc[:publishDate]}"
        content = nil
        pdf_file = disc[:filePath]
        if pdf_file.end_with?(".pdf")
          io     = open(disc[:filePath])
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
          txt_path = disc[:filePath].gsub("\.pdf", ".txt")
          open(txt_path, "w") do |file|
            file << content
          end
          io.close
          disc.update_attributes!(:filePath => txt_path, :isParsed => true) 
          File.delete(pdf_file)
        else
          puts "Unsupported suffix #{disc[:filePath]}"
          return
        end
      rescue Exception => e
        puts "Failed to parse content for disclosure #{disc[:filePath]}, #{e.class.name}"
        puts e.backtrace
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
      
      {
        :code => code, :name => name, :fileURL => fileURL, 
        :disclosureCode => disclosureCode, :disclosureTitle => disclosureTitle,
        :disclosureType => disclosureType, :publishDate => publishDate
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
  
    # Parse disclosures from PDF to txt
    def parse_disclosures
      disclosures = Disclosure.where(:isParsed => false).asc(:publishTime).limit(100)
      pool = Concurrent::FixedThreadPool.new(5)
      disclosures.each {|disc|
        pool.post {
          puts "Parsing #{disc[:disclosureCode]} #{disc[:publishTime]} #{disc[:disclosureTitle]}"
          parse_disclosure_content(disc)
          
        }
      }
      pool.shutdown
      pool.wait_for_termination
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
    #RubyProf.measure_mode = RubyProf::MEMORY
    #RubyProf.start
    crawler.crawl_disclosure
    #result = RubyProf.stop
  when "download"
    crawler.crawl_disclosure_content
  when "parse-content"
    crawler.parse_disclosures
  end
  

# print a flat profile to text
#printer = RubyProf::GraphPrinter.new(result)
#printer.print(STDOUT)
end
