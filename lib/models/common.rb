require_relative 'mongo_document'

# Must load config before requiring any model
MODEL_PATH = File.absolute_path(File.dirname(__FILE__))
CFG_PATH = File.join(MODEL_PATH, '/../../config')
config_file = File.join(CFG_PATH, 'mongodb.yml')
MongoDocument.load!(config_file)

