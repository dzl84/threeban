require_relative 'common'

class Disclosures
  include MongoDocument

  store_in :collection => 'disclosures', :session => 'default'

  field :name, :type => String
  field :code, :type => String
  field :filePath, :type => String
  field :disclosureCode, :type => String
  field :disclosureTitle, :type => String
  field :disclosureType, :type => String
  field :publishDate, :type => Date
  field :publishTime, :type => Time
  field :crawledDate, :type => Time
end
