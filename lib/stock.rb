require_relative "http_helper"

module Parser
  class StockPriceParser
    def self.parse_stock(id)
      if id.start_with?("6")
        id = "sh#{id}"
      else
        id ="sz#{id}"
      end
      httpclient = HTTPHelper.new("http://hq.sinajs.cn")
      path = "/list=#{id}"
      resp = httpclient.get(path)
      result = resp.body.split("\"")[1].split(",")
      cur_price = result[3]
      buy1_price = result[11]
      sell1_price = result[21]
      [cur_price, buy1_price, sell1_price]
    end
  end
end

if __FILE__ == $0
  include Parser
  r = StockPriceParser.parse_stock("601006")
  puts r
end