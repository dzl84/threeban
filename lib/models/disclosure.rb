require_relative 'base'

class Disclosure
  include Mongoid::Document

  field :name, :type => String
  field :code, :type => String
  field :fileURL, :type => String
  field :disclosureCode, :type => String
  field :disclosureTitle, :type => String
  field :disclosureType, :type => String
  field :publishDate, :type => Date
  field :publishTime, :type => Time
  field :isDownloaded, :type => Boolean, :default => false
  field :filePath, :type => String
  field :isContentParse, :type => Boolean, :default => false
  field :txtPath, :type => String
end
