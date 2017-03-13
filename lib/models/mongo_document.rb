require 'yaml'
require 'date'
# require 'utils'
require 'mongo'
include Mongo

module MongoDocument
  class Session
    DEFAULT_PORT = 27017

    def initialize(config, session)
      @session = config['sessions'][session] or raise "No session '#{session}' defined!"
      @hosts = @session['hosts'] or raise "No hosts defined in session '#{session}'!"
      @database = @session['database'] or raise "No database defined in session '#{session}'!"
      @username = @session['username']
      @password = @session['password']
    end

    def client
      if !@client
        if @hosts.size == 1
          host, port = @hosts[0].split ':'
          port = port ? port.to_i : DEFAULT_PORT
          @client = Mongo::Client.new("mongodb://#{host}:#{port}")
        else
          @client = Mongo::ReplicaSetClient.new(@hosts)
        end
        Mongo::Logger.logger.level = ::Logger::INFO
      end
      @client
    end

    def db
      if !@db
        @db = client.use(@database)
        if @username && !@db.authenticate(@username, @password)
          @db = nil
          raise "Authentication failed for user #{@username} in database #{@database}"
        end
      end
      @db
    end

    def [](coll)
      db[coll]
    end
  end

  class Collection
    include Enumerable
    attr_accessor :cursor

    def initialize(model, cursor)
      @model = model
      @cursor = cursor
    end

    def each
      while @cursor.has_next?
        doc = @model.new @cursor.next
        yield doc
      end
    end
  end

  class Boolean
  end

  FIELD_TYPES = [String, Integer, Float, Time, Date, Boolean, Hash, Array]

  class << self
    def load!(config_file)
      env = ENV['RACK_ENV'] or raise "'RACK_ENV' is not defined!"
      config = YAML.load(File.read(config_file))
      @config = config[env] or raise "No '#{env}' environment is defined in #{config_file}!"
    end

    def config
      @config or raise "No config is loaded!"
    end

    def convert(v, t)
      if v.is_a? t
        if t <= Time
          # to UTC time
          r = v.dup.utc
        else
          r = v
        end
      elsif v.nil?
        r = nil
      else
        # "case t when String ..." doesn't work?!
        case
        when t == String
          r = v.to_s
        when t == Integer
          r = v.to_i
        when t == Float
          r = v.to_f
        when t == Boolean
          r = v ? true : false
        when t == Date
          # MongoDB doesn't support Date type. However we support it here. When being saved
          # to MongoDB, it's converted to a UTC time. See method save! for more.
          if v.is_a? Time
            r = v.dup.utc.to_date
          elsif v.is_a? String
            r = Date.parse v
          else
            error = true
          end
        when t == Time
          if v.is_a? String
            r = Time.parse v
          else
            error = true
          end
        else
          error = true
        end
      end
      raise ArgumentError, "Cannot convert '#{v}' to type '#{t}'!" if error
      r
    end

  end

  def initialize(doc = nil)
    @attrs = self.class.defaults.dup
    if doc
      doc.each do |document|
        document.each do |k, v|
          self[k] = v
        end
      end
    end
  end

  def to_s
    str = attrs.to_a.map {|k, v| "#{k}:#{v}" }.join ','
    "<#{self.class}: #{str}>"
  end

  def to_h
    h = attrs.clone
    h[:id] = id.to_s
    h.delete :_id
    h
  end

  def attrs
    @attrs
  end

  def [](k)
    attrs[k.to_sym]
  end

  def []=(k, v)
    field = self.class.fields[k.to_sym]
    if field
      attrs[k.to_sym] = MongoDocument.convert(v, field[:type])
    else
      attrs[k.to_sym] = v
    end
  end

  def id
    attrs[:_id]
  end
  alias_method :_id, :id

  def ==(obj)
    obj.is_a?(self.class) && obj.id == id
  end

  def collection
    self.class.collection
  end

  def save!
    doc = attrs.dup
    self.class.fields.each do |k, v|
      if v[:type] == Date
        doc[k] = self[k].to_utc_time
      end
    end
    if id
      collection.update({:_id => id}, doc)
    else
      attrs[:_id] = collection.insert(doc)
    end
    true
  end

  def save
    save! rescue false
  end

  def delete
    collection.remove(:_id => id)
    attrs.delete :_id
  end

  # TODO: add a reload method
  # def reload
  # end

  def self.included(cls)
    cls.instance_eval do
      def fields
        @fields ||= {}
      end

      def defaults
        @defautls ||= {}
      end

      def field(name, opts = {})
        type = opts[:type] || String
        raise "Unsupported type '#{type}'!" if !FIELD_TYPES.include? type
        sym = name.to_sym
        fields[sym] = { :type => type }
        if opts.has_key? :default
          defaults[sym] = MongoDocument.convert(opts[:default], type)
        end

        define_method(sym) do
          self[sym]
        end

        define_method("#{name}=".to_sym) do |v|
          self[sym] = v
        end
      end

      def index(spec, opts = {})
        real = config['options']['index'] rescue false
        collection.create_index(spec, opts) if real
      end

      def validates(*args)
        raise "Not supported!"
      end

      def config
        MongoDocument.config
      end

      def store_in(opts)
        @collection = opts[:collection] or raise "No collection argument!"
        session = (opts[:session] || 'default').to_s
        @session = Session.new(config, session)
      end

      def session
        @session
      end

      def collection
        raise "No session or collection is defined for class #{self}. You're probably missing store_in in the class definition." \
          unless @session && @collection
        @session[@collection]
      end

      def create!(attrs = {})
        obj = self.new attrs
        obj.save!
        obj
      end

      def create(attrs = {})
        create!(attrs) rescue nil
      end

      # Updated for ruby mongo driver 2.4.1
      def first(opts = {})
        opts[:limit] = 1 
        doc = collection.find(nil, opts)
        doc ? self.new(doc) : nil
      end

      # Updated for ruby mongo driver 2.4.1
      def last(opts = {})
        opts[:limit] = 1
        opts[:sort] = {:_id => -1} unless opts[:sort]
        doc = collection.find(nil, {:limit => 1, :sort => {:_id => -1}})
        doc ? self.new(doc) : nil
      end

      def find_one(selector, opts = {})
        doc = collection.find_one(selector, opts)
        doc ? self.new(doc) : nil
      end

      def find(selector = {}, opts = {})
        view = collection.find(selector, opts)
        view
      end

      # This method works when new field is appended to existing doc
      # For example: doc = { 'a' => 10 }
      # It works with find_or_create({'a' => 10}, {'b' => 20})
      # It does not work for find_or_create({'a' => 10}, {'a' => 20})
      def find_or_create(selector, attrs)
        collection.find_and_modify(
          :query => selector,
          :update => { '$setOnInsert' => attrs },
          :upsert => true,
          :new => true
        )
      end

      # This method works for only value is updated
      # For example: doc = { 'a' => 10 }
      # It works with find_and_upsert({'a' => 10}, {'a' => 20})
      def find_and_upsert(selector, attrs)
        collection.find_and_modify(
          :query => selector,
          :update => attrs,
          :upsert => true,
          :new => true
        )
      end

      def upsert(selector, document)
        collection.update_one(selector, document, {:upsert => true})
      end
      
      def update(selector, document)
        collection.update(selector, document)
      end

      def delete_all(selector = {})
        collection.remove(selector)
      end

      def count(selector = {})
        collection.count :query => selector
      end

    end
  end
end

