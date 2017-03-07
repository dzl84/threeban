require_relative 'common'

class TradeData
  include MongoDocument

  store_in :collection => 'tradedata', :session => 'default'

  field :name, :type => String
  field :code, :type => String
  field :date, :type => String
  field :buy1, :type => Float
  field :buy1_amount, :type => Integer
  field :sell1, :type => Float
  field :sell1_amount, :type => Integer
  field :total_deal, :type => Float
  field :total_amount, :type => Integer
  field :has_trade, :type => Boolean

end
