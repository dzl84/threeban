require 'net/http'
require 'net/https'

class HTTPHelper

  def initialize host, useProxy=false
    @host = host
    @cookie = {}
    @isHTTPS = host.start_with?('https')
    uri = URI.parse(host)
    @http = Net::HTTP.new(uri.host, uri.port)
    if useProxy && ENV['http_proxy']
      proxy = URI.parse(ENV['http_proxy'])
      @http = Net::HTTP::Proxy(proxy.host, proxy.port).new(uri.host, uri.port)
    end
    if @isHTTPS
      @http.use_ssl = true
      @http.ssl_version = :TLSv1
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
  end

  def setCookie cookie
    idx = cookie.index('=')
    idy = cookie.index(';')
    key = cookie[0..idx-1]
    value = cookie[idx+1..idy-1]
    @cookie[key] = value
  end

  def getCookieStr
    str = ''
    @cookie.each {|key, value|
      str = "#{str} #{key}=#{value};"
    }
    str
  end

  def getCookies
    @cookie
  end

  def getCookieValue key
    return @cookie[key]
  end

  def post path, data, headers={}
    headers = headers.merge({"Cookie" => self.getCookieStr}) if !@cookie.empty?
    resp = @http.post(path, data, headers)
    newcookie = resp.to_hash['set-cookie']
    newcookie.each {|cookie| self.setCookie(cookie)} if newcookie
    resp
  end

  def get path, headers={}
    headers = headers.merge({"Cookie" => self.getCookieStr}) if !@cookie.empty?
    resp = @http.get(path, headers)
    newcookie = resp.to_hash['set-cookie']
    newcookie.each {|cookie| self.setCookie(cookie)} if newcookie
    resp
  end
end