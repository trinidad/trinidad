module Trinidad
  class LogFormatter < Java::JavaUtilLogging::Formatter
    
    def initialize(format = nil, time_zone = nil)
      super()
      @format = format ? 
        Java::JavaText::SimpleDateFormat.new(format) : 
          Java::JavaText::SimpleDateFormat.new
      case time_zone
      when Java::JavaUtil::Calendar then
        @format.calendar = time_zone
      when Java::JavaUtil::TimeZone then
        @format.time_zone = time_zone
      when String then
        time_zone = Java::JavaUtil::TimeZone.getTimeZone(time_zone)
        @format.time_zone = time_zone
      when Numeric then
        time_zones = Java::JavaUtil::TimeZone.getAvailableIDs(time_zone)
        if time_zones.length > 0
          time_zone = Java::JavaUtil::TimeZone.getTimeZone(time_zones[0])
          @format.time_zone = time_zone
        end
      end if time_zone
      @writer = java.io.StringWriter.new
    end

    JDate = Java::JavaUtil::Date
    
    def format(record)
      timestamp = @format.synchronized do 
        @format.format JDate.new(record.millis)
      end
      level = record.level.name
      message = formatMessage(record)

      out = "#{timestamp} #{level}: #{message}"
      out << formatThrown(record).to_s
      out << "\n"
    end
    
    private
    
    def formatThrown(record)
      @writer.synchronized do
        @writer.getBuffer.setLength(0)
        print_writer = java.io.PrintWriter.new(@writer)
        print_writer.println
        record.thrown.printStackTrace(print_writer)
        print_writer.close
        return @writer.toString
      end if record.thrown
    end
    
  end
end
