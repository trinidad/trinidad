module Trinidad
  module Lifecycle
    class Base
      include Trinidad::Tomcat::LifecycleListener
      attr_reader :web_app
      alias_method :webapp, :web_app

      def initialize(web_app)
        @web_app = web_app
      end

      def lifecycleEvent(event)
        case event.type
        when Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT then
          context = event.lifecycle
          configure_defaults(context)
        end
      end

      def configure_defaults(context)
        remove_defaults(context)
        configure_logging(context)
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

      def configure_logging(context)
        Trinidad::Logging.configure_web_app(web_app, context)
      end
      
    end
  end
end
