require_relative 'common'

class Account
  include MongoDocument

  store_in :collection => 'account', :session => 'default'

  field :name, :type => String

end
