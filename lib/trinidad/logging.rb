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
      @@configured = true
      
      root_logger = JUL::Logger.getLogger('')
      level = parse_log_level(log_level, :INFO)
      
      out_handler = new_console_handler JRuby.runtime.out
      out_handler.formatter = console_formatter

      err_handler = new_console_handler JRuby.runtime.err
      err_handler.formatter = console_formatter
      err_handler.level = level.intValue > JUL::Level::WARNING.intValue ?
        level : JUL::Level::WARNING # only >= WARNING on STDERR
      
      root_logger.synchronized do
        root_logger.handlers.to_a.each do |handler|
          root_logger.remove_handler(handler) if handler.is_a?(JUL::ConsoleHandler)
        end

        root_logger.add_handler(out_handler)
        root_logger.add_handler(err_handler)
        set_log_level(root_logger, level)
      end
      adjust_tomcat_loggers
      
      root_logger
    end
    
    # Force logging (re-)configuration.
    # @see #configure
    def self.configure!(log_level = nil)
      ( @@configured = false ) || configure(log_level)
    end
    
    def self.configure_web_app!(web_app, context)
      configure_web_app!(web_app, context, true)
    end
    
    # Configure logging for a web application.
    def self.configure_web_app(web_app, context, reset = nil)
      param_name, param_value = 'jruby.rack.logging', 'JUL'
      # 1. delegate (jruby-rack) servlet log to JUL
      if set_value = web_app_context_param(web_app, context, param_name)
        return nil if set_value.upcase != param_value
      else
        context.add_parameter(param_name, param_value)
      end
      # 2. use Tomcat's JUL logger name (unless set) :
      param_name = 'jruby.rack.logging.name'
      unless logger_name = web_app_context_param(web_app, context, param_name)
        # for a context path e.g. '/foo' most likely smt of the following :
        # org.apache.catalina.core.ContainerBase.[Tomcat].[localhost].[/foo]
        context.add_parameter(param_name, logger_name = context.send(:logName))
      end
      configure # make sure 'global' logging is configured
      
      logger = JUL::Logger.getLogger(logger_name) # exclusive for web app
      logger.handlers.each { |h| logger.remove_handler(h); h.close } if reset
      # avoid duplicate calls - do not configure (e.g. FileHandler) twice :
      return false unless logger.handlers.empty?
      
      logging = web_app.logging
      
      logger.level = parse_log_level(logging[:level], nil)
      # delegate to root (console) output only in development mode :
      logger.use_parent_handlers = logging[:use_parent_handlers]
      # logging:
      #  file:
      #    dir: log # [RAILS_ROOT]/log
      #    prefix: production
      #    suffix: .log
      if file = logging[:file]
        prefix, suffix = file[:prefix], file[:suffix] # {prefix}{date}{suffix}
        file_handler = FileHandler.new(file[:dir] || file[:directory], prefix, suffix)
        file_handler.rotatable = file.key?(:rotatable) ? file[:rotatable] : file[:rotate]
        file_handler.buffer_size = file[:buffer_size] if file[:buffer_size]
        format = file.key?(:format) ? file[:format] : logging[:format]
        file_handler.formatter = web_app_formatter(format) # nil uses default
        logger.add_handler(file_handler)
      end
      logger
    end
    
    protected
    
    def self.console_formatter
      MessageFormatter.new
    end
    
    def self.web_app_formatter(format = nil)
      # format used by Rails "2012-06-13 16:42:21 +0200"
      DefaultFormatter.new(format.nil? ? 'yyyy-MM-dd HH:mm:ss Z' : format)
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
    
    def self.set_log_level(logger, level)
      logger.level = level; LogFactory.getLog(logger.name)
    end
    
    def self.adjust_tomcat_loggers
      # org.apache.coyote.http11.Http11Protocol   INFO: Initializing ProtocolHandler ["http-bio-3000"]
      # org.apache.catalina.core.StandardService  INFO: Starting service Tomcat
      # org.apache.catalina.core.StandardEngine   INFO: Starting Servlet Engine: Apache Tomcat/7.0.27
      # org.apache.catalina.startup.ContextConfig INFO: No global web.xml found
      # org.apache.coyote.http11.Http11Protocol   INFO: Starting ProtocolHandler ["http-bio-3000"]
      name = 'org.apache.catalina.core.StandardService'
      if logger = JUL::Logger.getLogger(name)
        set_log_level(logger, JUL::Level::WARNING)
      end
      name = 'org.apache.catalina.startup.ContextConfig'
      if logger = JUL::Logger.getLogger(name)
        set_log_level(logger, JUL::Level::WARNING)
      end
    end
    
    def self.web_app_context_param(web_app, context, name)
      context.find_parameter(name) || web_app.web_xml_context_param(name)
    end
    
    JUL::ConsoleHandler.class_eval do
      field_accessor :sealed rescue nil
      field_writer :writer rescue nil
    end
    
    def self.new_console_handler(stream)
      handler = JUL::ConsoleHandler.new # sets output stream to System.err
      handler.writer = nil if handler.respond_to?(:writer=) # avoid writer.close
      if handler.respond_to?(:sealed) && handler.sealed
        handler.sealed = false # avoid manager security checks
        handler.setOutputStream(stream) # closes previous writer if != null
        handler.sealed = true
      else
        handler.setOutputStream(stream)
      end
      handler
    end
    
    if ( Java::JavaClass.for_name('rb.trinidad.logging.FileHandler') rescue nil )
      FileHandler = Java::RbTrinidadLogging::FileHandler # recent trinidad_jars
    else
      # we'd achieve logging to a production.log file while rotating it (daily)
      class FileHandler < Java::OrgApacheJuli::FileHandler # :nodoc

        field_reader :directory, :prefix, :suffix
        field_accessor :rotatable, :bufferSize => :buffer_size

        # JULI::FileHandler internals :
        field_accessor :date => :_date # current date string e.g. 2012-06-26

        def initialize(directory, prefix, suffix)
          super(directory, prefix, suffix)
          self._date = nil # to openWriter on first #publish(record)
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
          date = _date
          super # sets `date = null`
          # the additional trick here is to rotate the closed file
          synchronized do
            # we're normally in the lock here (from #publish) 
            # thus we do not perform any more synchronization
            dir = java.io.File.new(directory).getAbsoluteFile
            log = java.io.File.new(dir, prefix + "" + suffix)
            if log.exists
              if ! date || date.empty?
                date = log.lastModified
                # we abuse Timestamp to get a date formatted !
                # just like super does internally (just in case)
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
        if context_name(record.getLoggerName)
          (lns = LINE_SEP) == msg[-1, 1] ? msg : msg << lns
        else
          msg << LINE_SEP
        end
      end
      
      # e.g. org.apache.catalina.core.ContainerBase.[Tomcat].[localhost].[/foo]
      # or org.apache.catalina.core.ContainerBase.[Tomcat].[localhost].[default]
      WEB_APP_LOGGER_NAME = /^org\.apache\.catalina\.core\.ContainerBase.*?\[(.*?)\]$/
      
      private
      def context_name(name)
        ( match = (name || '').match(WEB_APP_LOGGER_NAME) ) && match[1]
      end
      
    end
    
    if ( Java::JavaClass.for_name('rb.trinidad.logging.DefaultFormatter') rescue nil )
      DefaultFormatter = Java::RbTrinidadLogging::DefaultFormatter # recent trinidad_jars
    else
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
    
  end
  LogFormatter = Logging::DefaultFormatter # backwards compatibility
end
