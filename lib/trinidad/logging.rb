require 'jruby'
require 'fileutils'

module Trinidad
  module Logging
    
    JUL = Java::JavaUtilLogging
    LogFactory = Java::OrgApacheJuliLogging::LogFactory
    
    @@configured = nil
    
    # Configure the "global" Trinidad logging.
    def self.configure(log_level = nil)
      return false if @@configured
      
      root_logger = JUL::Logger.getLogger('')
      level = parse_log_level(log_level, :INFO)

      out_handler  = JUL::ConsoleHandler.new
      out_handler.setOutputStream JRuby.runtime.out
      out_handler.formatter = console_formatter

      err_handler  = JUL::ConsoleHandler.new
      err_handler.setOutputStream JRuby.runtime.err
      err_handler.formatter = console_formatter
      err_handler.level = level.intValue > JUL::Level::WARNING.intValue ?
        level : JUL::Level::WARNING # only >= WARNING on STDERR
      
      root_logger.synchronized do
        root_logger.handlers.to_a.each do |handler|
          root_logger.remove_handler(handler) if handler.is_a?(JUL::ConsoleHandler)
        end

        root_logger.add_handler(out_handler)
        root_logger.add_handler(err_handler)
        root_logger.level = level
      end
      adjust_tomcat_loggers
      
      @@configured = true
      root_logger
    end
    
    # Force logging (re-)configuration.
    # @see #configure
    def self.configure!(log_level = nil)
      @@configured = false
      configure(log_level)
    end
    
    # Configure logging for a web application.
    def self.configure_web_app(web_app, context)
      param_name, param_value = 'jruby.rack.logging', 'JUL'
      # 1. delegate (jruby-rack) servlet log to JUL
      if set_value = context.find_parameter(param_name)
        return nil if set_value.upcase != param_value
      else
        context.add_parameter(param_name, param_value)
      end
      # 2. use Tomcat's JUL logger name (unless set) :
      param_name = 'jruby.rack.logging.name'
      unless logger_name = context.find_parameter(param_name)
        # for a context path e.g. '/foo' most likely smt of the following :
        # org.apache.catalina.core.ContainerBase.[Tomcat].[localhost].[/foo]
        context.add_parameter(param_name, logger_name = context.send(:logName))
      end
      configure # make sure 'global' logging if configured
      
      logger = JUL::Logger.getLogger(logger_name) # exclusive for web app
      # avoid duplicate calls - do not configure our FileHandler twice :
      return false if logger.handlers.find { |h| h.is_a?(FileHandler) }
      level = parse_log_level(web_app.log, nil)
      logger.level = level # inherits level from parent if nil
      # delegate to root (console) output only in development mode :
      logger.use_parent_handlers = ( web_app.environment == 'development' )
      
      prefix, suffix = web_app.environment, '.log' # {prefix}{date}{suffix}
      file_handler = FileHandler.new(web_app.log_dir, prefix, suffix)
      file_handler.rotatable = true # {prefix}{date}{suffix}
      file_handler.formatter = web_app_formatter
      logger.add_handler(file_handler)
      logger
    end
    
    protected
    
    def self.console_formatter
      MessageFormatter.new
    end
    
    def self.web_app_formatter
      # format used by Rails "2012-06-13 16:42:21 +0200"
      DefaultFormatter.new("yyyy-MM-dd HH:mm:ss Z")
    end
    
    private
    
    def self.parse_log_level(log_level, default = nil)
      log_level = log_level && log_level.to_s.upcase
      unless JUL::Level.constants.find { |level| level.to_s == log_level }
        log_level = { # try mapping common level names to JUL names
          'ERROR' => 'SEVERE', 'WARN' => 'WARNING', 'DEBUG' => 'FINE' 
        }[log_level]
        log_level = default ? default.to_s.upcase : nil unless log_level
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
    
    # we'd achieve logging to a production.log file while rotating it (daily)
    class FileHandler < Java::OrgApacheJuli::FileHandler # :nodoc
      
      field_reader :directory, :prefix, :suffix
      field_accessor :rotatable, :bufferSize => :buffer_size
      
      # JULI::FileHandler internals :
      field_accessor :date => :_date # current date string e.g. 2012-06-26
      
      def initialize(directory, prefix, suffix)
        super(directory, prefix, suffix)
        self._date = '' # to openWriter on first #publish(record)
      end
      
      def openWriter
        # NOTE: following code is heavily based on super's internals !
        synchronized do
          # we're normally in the lock here (from #publish) 
          # thus we do not perform any more synchronization
          prev_rotatable = self.rotatable
          begin
            self.rotatable = false
            # thus current file name will be always {prefix}{suffix} :
            # due super's `prefix + (rotatable ? _date : "") + suffix`
            super
          ensure
            self.rotatable = prev_rotatable
          end
        end
      end

      def close
        @_close = true
        super
        @_close = nil
      end
      
      def closeWriter
        super
        # the additional trick here is to rotate the closed file
        synchronized do
          # we're normally in the lock here (from #publish) 
          # thus we do not perform any more synchronization
          dir = java.io.File.new(directory).getAbsoluteFile
          log = java.io.File.new(dir, prefix + "" + suffix)
          if log.exists
            date = _date
            if date.empty?
              date = log.lastModified
              # we're abuse Timestamp to get a date formatted !
              # just like the super does internally (just in case)
              date = java.sql.Timestamp.new(date).toString[0, 10]
            end
            today = java.lang.System.currentTimeMillis
            today = java.sql.Timestamp.new(today).toString[0, 10]
            return if date == today # no need to rotate just yet
            to_file = java.io.File.new(dir, prefix + date + suffix)
            if to_file.exists
              file = java.io.RandomAccessFile.new(to_file, 'rw')
              file.seek(file.length)
              log_channel = java.io.FileInputStream.new(log).getChannel
              log_channel.transferTo(0, log_channel.size, file.getChannel)
              file.close
              log_channel.close
              log.delete
            else
              log.renameTo(to_file)
            end
          end
        end if rotatable && ! @_close
      end
      
    end
    
    # We're truly missing a #formatThrown exception helper method.
    JUL::Formatter.class_eval do
      
      LINE_SEP = java.lang.System.getProperty("line.separator")
      
      protected
      def formatThrown(record)
        if record.thrown
          writer = java.io.StringWriter.new(1024)
          print_writer = java.io.PrintWriter.new(writer)
          print_writer.println
          record.thrown.printStackTrace(print_writer)
          print_writer.close
          return writer.toString
        end
      end
      
    end
    
    # A message formatter only prints the log message (and the thrown value).
    class MessageFormatter < JUL::Formatter # :nodoc
      
      def format(record)
        msg = formatMessage(record)
        msg << formatThrown(record).to_s
        # since we're going to print Rails.logger logs and they tend
        # to already have the ending "\n" handle such cases nicely :
        if web_app_path(record.getLoggerName)
          (lns = LINE_SEP) == msg[-1, 1] ? msg : msg << lns
        else
          msg << LINE_SEP
        end
      end
      
      # e.g. org.apache.catalina.core.ContainerBase.[Tomcat].[localhost].[/foo]
      WEB_APP_LOGGER_NAME = /org\.apache\.catalina\.core\.ContainerBase.*?\[(\/.*?)\]$/
      
      private
      def web_app_path(name)
        ( match = (name || '').match(WEB_APP_LOGGER_NAME) ) && match[1]
      end
      
    end
    
    # A formatter that formats application file logs (e.g. production.log).
    class DefaultFormatter < JUL::Formatter # :nodoc

      # Allows customizing the date format + the time zone to be used.
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
        (lns = "\n") == out[-1, 1] ? out : out << lns
      end

    end
  end
  LogFormatter = Logging::DefaultFormatter # backwards compatibility
end
