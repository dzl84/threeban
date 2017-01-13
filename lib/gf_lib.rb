require 'rubygems'
require 'net/http'
require 'net/https'
require_relative 'http_helper'
require_relative 'ocr'
require 'json'


$http = HTTPHelper.new("https://trade.gf.com.cn", true)
$username = "*F0*F5*CF*A3*FC*99vT*CEJ*80h*9B*E9*1B*B3G*97*883*91G*16bw*22*A05*A8*CCL8G*97*883*91G*16bw*22*A05*A8*CCL8G*97*883*91G*16bw*22*A05*A8*CCL8*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00"
$password = "*D9F*D3*DD*FEc*E0*C4l*5B*C0I*CC*06*27*84G*97*883*91G*16bw*22*A05*A8*CCL8G*97*883*91G*16bw*22*A05*A8*CCL8G*97*883*91G*16bw*22*A05*A8*CCL8*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00*00"

$exchange_type = {'SH'=>1, 'SZ'=>2}

def login
  puts "Getting the captcha code and cookie"
  login = false

  until login do
    cookie, captcha = getCaptcha($http)
    puts "Captcha: #{captcha}"
    if captcha.size != 5
      puts "captcha may not be correct, retrying..."
      next
    end

    headers = {
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:22.0) Gecko/20100101 Firefox/22.0',
      'Accept'=>'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Encoding'=>'gzip, deflate',
      'Accept-Language'=>'en-US,en;q=0.5',
      'Connection'=>'keep-alive',
      'Host'=>	'trade.gf.com.cn',
      'cookie' => cookie
    }

    data = "username=#{$username}&password=#{$password}&tmp_yzm=#{captcha}&mac=00-50-56-04-07-CB%2C10.127.240.136&authtype=2&loginType=2&origin=web"
    resp = $http.post("/login", data, headers)
    puts resp.body
    puts resp['Set-Cookie']
    result = JSON.parse(resp.body)
    login = result["success"]
    puts "Login failed, retrying..." unless login
  end
end

def getWorkbench
  puts "getting workbench"
  sid = $http.getCookieValue('dse_sessionId')
  path = "/workbench/index.jsp"
  data = "menu=&node=&params=&origin=web&prodtype="
  resp = $http.post(path, data)
  puts "result:"
  puts resp.body
end

def queryFund
  puts "query fund"
  sid = $http.getCookieValue('dse_sessionId')
  path = "/entry?classname=com.gf.etrade.control.StockUF2Control&method=queryFund&dse_sessionId=#{sid}&_dc=1405663628165"
  resp = $http.get(path)
  puts "result:#{resp.code}"
  puts resp.body
end

def getMenu
  puts "getting menu"
  sid = $http.getCookieValue('dse_sessionId')
  path = "/entry?classname=com.gf.etrade.control.MenuControl&method=getMenu&id=stock&dse_sessionId=#{sid}"
  data = "node=xnode-136"
  resp = $http.post(path, data)
  puts "result: #{resp.code}"
  puts resp.body
end

def getStockPriceAmount code
  puts "getting price/amount for #{code}"
  sid = $http.getCookieValue('dse_sessionId')
  path = "/entry"
  data = "classname=com.gf.etrade.control.StockUF2Control&method=getStockHQ&stock_code=#{code}&dse_sessionId=#{sid}"
  puts "data:#{data}"
  resp = $http.post(path, data)
  puts "result:"
  puts resp.body
end

def getSellPrice code
  #puts "getting sell price for #{code} now"
  sid = $http.getCookieValue('dse_sessionId')
  path = "/entry"
  data = "classname=com.gf.etrade.control.StockUF2Control&method=getStockHQ&stock_code=#{code}&dse_sessionId=#{sid}"
  #puts "data:#{data}"
  resp = $http.post(path, data)
  #puts "result:"
  #puts resp.body
  j = JSON.parse(resp.body[/.*hq:([^}]*})/,1])
  j["sale_price1"].to_f
end

def buy code, amount, price
  loc = code[0] == '6'? 'SH':'SZ'
  type = $exchange_type[loc]
  sid = $http.getCookieValue('dse_sessionId')
  path = "/entry?classname=com.gf.etrade.control.StockUF2Control&method=entrust&dse_sessionId=#{sid}"
  data = "dse_sessionId=#{sid}&stock_code=#{code}&exchange_type=#{type}&entrust_amount=#{amount}&entrust_price=#{price}&entrust_prop=0&entrust_bs=1"
  puts "data:#{data}"
  resp = $http.post(path, data)
  puts "result: #{resp.code}"
  puts resp.body
  puts resp['Set-Cookie']
end


if __FILE__ == $0
  login()

  $http.getDelays

  getStockPriceAmount '600011'

  start = Time.now
  puts start.strftime('%Y-%m-%d %H:%M:%S.%L %Z')
  start = Time.new(start.year, start.month, start.day, 21, 59, 19, "+08:00")
  puts Time.now < start
  until Time.now >= start
    sleep(1)
    puts "Wait...#{Time.now.strftime('%Y-%m-%d %H:%M:%S.%L %Z')}"
  end

  threads = []
  (1..3).each { |index|
    threads << Thread.new do
      sleep(index * 10)
      puts "T#{index}: ...#{Time.now.strftime('%Y-%m-%d %H:%M:%S.%L %Z')}"
      #queryFund
      #getStockPriceAmount(ARGV[0])
      #buy(ARGV[0], ARGV[1], ARGV[2])
    end
  }

  threads.each do |thread|
    thread.join
  end

end
