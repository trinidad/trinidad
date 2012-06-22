module Trinidad
  module Lifecycle
    module WebApp
      # Shared web application lifecycle hook, 
      # does #configure before the context starts.
      module Shared

        attr_reader :web_app
        alias_method :webapp, :web_app # #deprecated

        def initialize(web_app)
          @web_app = web_app
        end

        # @see Trinidad::Lifecycle::Base#before_start
        def before_start(event)
          super
          configure(event.lifecycle)
        end

        # Configure the web application before it's started.
        def configure(context)
          remove_defaults(context)
          configure_logging(context)
        end

        protected

        def configure_logging(context)
          Trinidad::Logging.configure_web_app(web_app, context)
        end

        private

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
        
      end
    end 
  end
end