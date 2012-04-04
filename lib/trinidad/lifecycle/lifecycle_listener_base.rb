module Trinidad
  module Lifecycle
    class Base
      include Trinidad::Tomcat::LifecycleListener
      attr_reader :webapp

      def initialize(webapp)
        @webapp = webapp
        @configured_logger = false
      end

      def lifecycleEvent(event)
        if Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT == event.type
          context = event.lifecycle
          configure_defaults(context)
        end
      end

      def configure_defaults(context)
        remove_defaults(context)
        configure_logging
      end

      def remove_defaults(context)
        context.remove_welcome_file('index.jsp')
        context.remove_welcome_file('index.htm')
        context.remove_welcome_file('index.html')

        jsp_servlet = context.find_child('jsp')
        context.remove_child(jsp_servlet) if jsp_servlet

        context.remove_servlet_mapping('*.jspx')
        context.remove_servlet_mapping('*.jsp')

        context.process_tlds = false
        context.xml_validation = false
      end

      def configure_logging
        return if @configured_logger

        log_path = File.join(@webapp.work_dir, 'log', "#{@webapp.environment}.log")
        log_file = java.io.File.new(log_path)

        unless log_file.exists
          log_file.parent_file.mkdirs
          log_file.create_new_file
        end

        jlogging = java.util.logging

        file_handler = jlogging.FileHandler.new(log_path, true)

        out_handler  = jlogging.ConsoleHandler.new
        out_handler.set_output_stream JRuby.runtime.out

        err_handler  = jlogging.ConsoleHandler.new
        err_handler.set_output_stream JRuby.runtime.err

        logger = jlogging.Logger.get_logger("")

        log_level = @webapp.log
        unless %w{ALL CONFIG FINE FINER FINEST INFO OFF SEVERE WARNING}.include?(log_level)
          puts "Invalid log level #{log_level}, using default: INFO"
          log_level = 'INFO'
        end

        level = jlogging.Level.parse(log_level)

        console_handler = logger.handlers.first
        logger.remove_handler(console_handler)

        logger.add_handler(file_handler)
        logger.add_handler(out_handler)
        logger.add_handler(err_handler)

        logger.handlers.each do |handler|
          handler.level = level
          handler.formatter = Trinidad::LogFormatter.new
        end

        logger.level = level

        @configured_logger = true
      end
    end
  end
end
