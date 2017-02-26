require_relative 'common'

class Companies
  include MongoDocument

  store_in :collection => 'companies', :session => 'default'

  field :name, :type => String
  field :code, :type => Int
  field :trade_type, :type => String
  field :industry, :type => String
  field :location, :type => String
  field :new_fin_report, :type => Boolean
  field :new_announce, :type => Boolean

end
