module Trinidad
  module Lifecycle
    module WebApp
      # Shared web application lifecycle hook, 
      # does #configure before the context starts.
      module Shared

        attr_reader :web_app
        alias_method :webapp, :web_app

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

          if jsp_wrapper = context.find_child('jsp')
            remove_servlet_mapping(context, 'jsp')
            context.remove_child(jsp_wrapper)
          end

          context.process_tlds = false
          context.xml_validation = false
        end

        # Remove all servlet mappings for given (servlet) name.
        def remove_servlet_mapping(context, name)
          find_servlet_mapping(context, name).each do
            |pattern| context.remove_servlet_mapping(pattern)
          end
        end
        
        # Find all servlet mappings for given (servlet) name.
        def find_servlet_mapping(context, name)
          name_mapping = []
          context.find_servlet_mappings.each do |pattern|
            mapping_for = context.find_servlet_mapping(pattern)
            name_mapping << pattern if mapping_for == name
          end
          name_mapping
        end
        
      end
    end
  end
end