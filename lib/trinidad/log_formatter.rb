module Trinidad
  class LogFormatter < Java::JavaUtilLogging::Formatter
    def initialize(format = "yyyy-MM-dd HH:mm:ss Z")
      @format = Java::JavaText::SimpleDateFormat.new format
      calendar = Java::JavaUtil::GregorianCalendar.new
      calendar.time_zone = Java::JavaUtil::SimpleTimeZone.new(0, 'UTC')
      @format.calendar = calendar
    end

    def format(record)
      timestamp = @format.format(Java::JavaUtil::Date.new record.millis)
      level = record.level.name
      message = record.message.chomp

      "#{timestamp} #{level}: #{message}\n"
    end
  end
end
