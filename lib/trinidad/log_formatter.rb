module Trinidad
  class LogFormatter < Java::JavaUtilLogging::Formatter
    def self.date_format
      @date_format ||= Java::JavaText::SimpleDateFormat.new "yyyy-MM-dd HH:mm:ss"
    end

    def format(record)
      timestamp = self.class.date_format.format(Java::JavaUtil::Date.new(record.millis))
      level = record.level.name
      message = record.message.chomp

      "#{timestamp} #{level}: #{message}\n"
    end
  end
end