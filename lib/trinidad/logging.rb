require 'jruby'

module Trinidad
  module Logging
    
    JUL = Java::JavaUtilLogging
    
    @@configured = nil
    
    # Configure the "global" Trinidad logging.
    def self.configure(log_level = nil)
      return false if @@configured
      
      root_logger = JUL::Logger.get_logger('')
      level = parse_log_level(log_level, :INFO)

      out_handler  = JUL::ConsoleHandler.new
      out_handler.set_output_stream JRuby.runtime.out

      err_handler  = JUL::ConsoleHandler.new
      err_handler.set_output_stream JRuby.runtime.err
      
      root_logger.handlers.to_a.each do |handler|
        root_logger.remove_handler(handler) if handler.is_a?(JUL::ConsoleHandler)
      end
      
      root_logger.add_handler(out_handler)
      root_logger.add_handler(err_handler)
      root_logger.handlers.each do |handler|
        handler.level = level
        handler.formatter = new_formatter
      end
      root_logger.level = level
      adjust_tomcat_loggers
      
      @@configured = true
    end
    
    # Force logging (re-)configuration.
    # @see #configure
    def self.configure!(log_level = nil)
      @@configured = false
      configure(log_level)
    end
    
    # Configure logging for a web application.
    def self.configure_web_app(web_app, context)
      level = parse_log_level(web_app.log, :INFO)

      log_path = File.join(web_app.work_dir, 'log', "#{web_app.environment}.log")
      log_file = java.io.File.new(log_path)

      unless log_file.exists
        log_file.parent_file.mkdirs
        log_file.create_new_file
      end

      logger = JUL::Logger.get_logger("")
      file_handler = JUL::FileHandler.new(log_path, true)
      logger.add_handler(file_handler)
      file_handler.level = level
      file_handler.formatter = new_formatter
      logger.level = level
    end
    
    def self.new_formatter
      # format used by Rails "2012-06-13 16:42:21 +0200"
      Formatter.new("yyyy-MM-dd HH:mm:ss Z")
    end
    
    private
    
    def self.parse_log_level(log_level, default = nil)
      log_level = log_level && log_level.to_s.upcase
      unless JUL::Level.constants.find { |level| level.to_s == log_level }
        log_level = { # try mapping common level names to JUL names
          'ERROR' => 'SEVERE', 'WARN' => 'WARNING', 'DEBUG' => 'FINE' 
        }[log_level]
        log_level = default ? default.to_s.upcase : nil
      end
      JUL::Level.parse(log_level) if log_level
    end
    
    def self.adjust_tomcat_loggers
      # org.apache.coyote.http11.Http11Protocol   INFO: Initializing ProtocolHandler ["http-bio-3000"]
      # org.apache.catalina.core.StandardService  INFO: Starting service Tomcat
      # org.apache.catalina.core.StandardEngine   INFO: Starting Servlet Engine: Apache Tomcat/7.0.27
      # org.apache.catalina.startup.ContextConfig INFO: No global web.xml found
      # org.apache.coyote.http11.Http11Protocol   INFO: Starting ProtocolHandler ["http-bio-3000"]
      logger = JUL::Logger.get_logger('org.apache.catalina.core.StandardService')
      logger.level = JUL::Level::WARNING if logger
      logger = JUL::Logger.get_logger('org.apache.catalina.startup.ContextConfig')
      logger.level = JUL::Level::WARNING if logger
    end
    
    class Formatter < JUL::Formatter

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
        (lnb = "\n") == out[-1, 1] ? out : out << lnb
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
  LogFormatter = Logging::Formatter # backwards compatibility
end
