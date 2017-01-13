require 'log4r'
require 'tzinfo'


######################################
#
# Log stuff
#

# This is to trigger the definitions of level constants in Log4r.
Log4r::Logger.root

LOG_LEVEL = {
  'debug' => Log4r::DEBUG,
  'info' => Log4r::INFO,
  'warn' => Log4r::WARN,
  'error' => Log4r::ERROR,
  'fatal' => Log4r::FATAL,
}

def setup_logger(name, file = nil)
  logger = Log4r::Logger.new name
  formatter = Log4r::PatternFormatter.new(:pattern => "[%l] %d :: %m")
  target = AppConfig['log']['output'] rescue 'console'
  level = AppConfig['log']['level'] rescue 'error'
  level = LOG_LEVEL[level]
  level = Log4r::ERROR unless level
  case target
  when 'console'
    Log4r::StderrOutputter.new('console', :level => level).formatter = formatter
    logger.add('console')
  when 'file'
    if file
      Log4r::FileOutputter.new(
        'file',
        :filename => File.join(LOG_PATH, file),
        :trunc => false,
        :level => level
      ).formatter = formatter
      logger.add('file')
    end
  end
  logger
end

def log
  Log4r::Logger['main'] || setup_logger('main')
end

def setup_default_logger(__file__)
  basename = File.basename(__file__, '.rb')
  setup_logger('main', "#{basename}.log")
end

######################################
#
# Time stuff
#

class Date
  # Convert a date to a utc time. For example, date '2015-01-01' will be
  # converted to a utc time '2015-01-01T00:00:00Z'
  # This is for saving date in MongoDB. Since MongoDB doesn't support Ruby Date,
  # it has to be converted to a Ruby time before saving.
  def to_utc_time
    t = self.to_time
    t = t + t.utc_offset
    t.utc
  end
end

def parse_time(str)
  return str if str.class <= Time
  i = str.to_i
  if i.to_s == str
    Time.at i
  else
    Time.parse str
  end
end

def milliseconds_to_time(m)
  Time.at(m / 1000, (m % 1000) * 1000)
end

def time_to_milliseconds(t)
  (t.to_i * 1000) + (t.tv_usec / 1000)
end

# DO NOT CHANGE TZ! THAT WILL INVALID ALL RECORDS OF RELATED TABLES IN DATABASE!
TZ_PA = TZInfo::Timezone.get "America/Los_Angeles"

# Convert a UTC time to PA local time.
def UTC_to_PA(t)
  TZ_PA.utc_to_local t
end

# Treat a local time as PA local time(no matter what local it really is) and convert it to a UTC time.
def PA_to_UTC(t)
  TZ_PA.local_to_utc t
end

MORNING_OPEN = Time.new(Time.now.year, Time.now.month, Time.now.day, 9, 30, 0)
MORNING_CLOSE = Time.new(Time.now.year, Time.now.month, Time.now.day, 11, 30, 0)
AFTERNOON_OPEN = Time.new(Time.now.year, Time.now.month, Time.now.day, 13, 0, 0)
AFTERNOON_CLOSE = Time.new(Time.now.year, Time.now.month, Time.now.day, 15, 0, 0)

def is_trading_time?
  now = Time.now
  return false if now.saturday? or now.sunday?
  return true if now.between?(MORNING_OPEN, MORNING_CLOSE) \
                      or now.between?(AFTERNOON_OPEN, AFTERNOON_CLOSE)
  return false
end

def after_trading_time?
  return true if Time.now > AFTERNOON_CLOSE
  return false
end

######################################
#
# Misc stuff
#

def sym_hash(h)
  pairs = h.map do |k, v|
    new_k = k.to_sym
    if v.is_a? Hash
      new_v = sym_hash(v)
    else
      new_v = v
    end
    [new_k, new_v]
  end
  Hash[pairs]
end

def ddd
  require 'byebug'
  debugger
end

