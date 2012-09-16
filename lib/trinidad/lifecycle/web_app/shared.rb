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
          adjust_context(context)
          remove_defaults(context)
          configure_logging(context)
        end

        protected
        
        def adjust_context(context)
          context.doc_base = web_app.doc_base if web_app.doc_base
          context.work_dir = web_app.work_dir if web_app.work_dir
        end
        
        def configure_logging(context)
          Trinidad::Logging.configure_web_app(web_app, context)
        end
        
        private

        def remove_defaults(context)
          context.remove_welcome_file('index.htm')
          context.remove_welcome_file('index.html')
          remove_jsp_support(context)
        end

        def remove_jsp_support(context)
          context.remove_welcome_file('index.jsp')
          if jsp_wrapper = context.find_child('jsp')
            remove_servlet_mapping(context, 'jsp')
            context.remove_child(jsp_wrapper)
          else
            logger.warn "[#{web_app.context_path}] jsp servlet not found"
          end
          context.process_tlds = false
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
        
        def logger
          @logger ||= Trinidad::Logging::LogFactory.
            getLog('org.apache.catalina.core.StandardContext')
        end
        
      end
    end
  end
end