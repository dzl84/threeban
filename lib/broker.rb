# encoding: UTF-8

require_relative "models"
require_relative "stock"
require 'pp'
include Parser

class Broker
  def initialize
    @history
    @history = ::Account.find({})
    @holds = []

    @history.each {|record|
      if record['buy']
        hold = @holds.select {|item| item['stock'] == record['buy']}
        if hold[0]
          hold[0]['price'] = (hold[0]['price']*hold[0]['amount'] + record['price']*record['amount'])/(hold[0]['amount'] + record['amount'])
          hold[0]['amount'] += record['amount']
        else
          hold = {'stock' => record['buy'],
                  'price' => record['price'],
                  'amount' => record['amount'],
                  'profit' => 0
                  }
          @holds << hold
        end
      elsif record['sell']
        hold = @holds.select {|item| item['stock'] == record['sell']}
        if hold[0] and hold[0]['amount'] >= record['amount']
          hold[0]['amount'] -= record['amount']
          hold[0]['profit'] = record['amount']*(record['price'] - hold[0]['price'])
        else
          puts "Error: insufficient #{record['sell']}"
        end
      end

    }
  end

  def show_holds
    pp @holds
  end

  def get_followed_topuser

  end

  def buy(spec)

    cur_price, buy1_price, sell1_price = StockPriceParser.parse_stock(spec["__code"])
    puts "follow: #{spec['topuser']}, buy: #{spec['__code']}, price: #{sell1_price}, amount: #{spec['cjsl']}"
    deal = {:follow => spec['topuser'],
      :buy => spec['__code'],
      :price => sell1_price.to_f,
      :amount => spec['cjsl'].to_i,
      :time => Time.now,
      :total => sell1_price.to_f * spec['cjsl'].to_i
    }
    ::Account.create!(deal)
  end

  def sell(spec)
    cur_price, buy1_price, sell1_price = StockPriceParser.parse_stock(spec["__code"])
    puts "follow: #{spec['topuser']}, sell: #{spec['__code']}, price: #{buy1_price}, amount: #{spec['cjsl']}"
    deal = {:follow => spec['topuser'],
            :sell => spec['__code'],
            :price => buy1_price.to_f,
            :amount => spec['cjsl'].to_i,
            :time => Time.now,
            :total => sell1_price.to_f * spec['cjsl'].to_i
    }

    ::Account.create!(deal)
  end


end