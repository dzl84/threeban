require_relative 'common'

class TopUser
  include MongoDocument

  store_in :collection => 'topUsers', :session => 'default'

  field :name, :type => String

end
