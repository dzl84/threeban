require 'mongoid'

# Must load config before requiring any model
MODEL_PATH = File.absolute_path(File.dirname(__FILE__))
CFG_PATH = File.join(MODEL_PATH, '/../../config')
config_file = File.join(CFG_PATH, 'mongoid.yml')
env = ENV['RACK_ENV'] or raise "'RACK_ENV' is not defined!"
Mongoid.load!(config_file, env.to_sym)

