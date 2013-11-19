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

        def before_init(event)
          #context = event.lifecycle
          #context.name = context.path if context.name
          super
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
          configure_default_servlet(context)
          configure_jsp_servlet(context)
          configure_logging(context)
        end

        protected

        def adjust_context(context)
          context_name = web_app.context_name
          # on (rolling) reloads the name may have been set already :
          if context_name && ! (context.name || '').index(context_name)
            context.name = context_name
          end

          context.doc_base = web_app.doc_base if web_app.doc_base
          context.work_dir = web_app.work_dir if web_app.work_dir
          context.aliases  = web_app.aliases  if web_app.aliases
          context.allow_linking = web_app.allow_linking

          context.caching_allowed = web_app.caching_allowed?
          context.cache_ttl = web_app.cache_ttl if web_app.cache_ttl
          if max_size = web_app.cache_max_size
            context.cache_max_size = max_size
          end
          if object_max_size = web_app.cache_object_max_size
            context.cache_object_max_size = object_max_size
          end
        end

        def configure_default_servlet(context)
          configure_builtin_servlet(context,
            web_app.default_servlet, Trinidad::WebApp::DEFAULT_SERVLET_NAME
          )
        end

        def configure_jsp_servlet(context)
          wrapper = configure_builtin_servlet(context,
            web_app.jsp_servlet, Trinidad::WebApp::JSP_SERVLET_NAME
          )
          context.process_tlds = false if wrapper == false # jsp servlet removed
          wrapper
        end

        def configure_logging(context)
          Trinidad::Logging.configure_web_app(web_app, context)
        end

        private

        def configure_builtin_servlet(context, servlet_config, name)
          name_wrapper = context.find_child(name)
          case servlet_config
          when true
            return true # nothing to do leave built-in servlet as is
          when false
            # remove what Tomcat set-up (e.g. use one from web.xml)
            remove_servlet_mapping(context, name)
            context.remove_child(name_wrapper)
            return false
          else
            wrapper, name = name_wrapper, name
            if servlet = servlet_config[:instance]
              wrapper = context.create_wrapper
              wrapper.name = name = servlet_config[:name] || name
              wrapper.servlet = servlet
              context.remove_child(name_wrapper)
              context.add_child(wrapper)
            elsif servlet_class = servlet_config[:class]
              wrapper.servlet_class = servlet_class
            end
            # do not remove wrapper but only "update" the default :
            wrapper.load_on_startup = ( servlet_config[:load_on_startup] ||
                name_wrapper.load_on_startup ).to_i
            add_init_params(wrapper, servlet_config[:init_params])
            if mapping = servlet_config[:mapping]
              # NOTE: we override the default mapping :
              remove_servlet_mapping(context, name)
              add_servlet_mapping(context, mapping, name)
              # else keep the servlet mapping as is ...
            end
            wrapper
          end
        end

        def remove_defaults(context)
          context.remove_welcome_file('index.htm')
          context.remove_welcome_file('index.html')
          context.remove_welcome_file('index.jsp')
        end

        def add_init_params(wrapper, params)
          return unless params
          params.each do |param, value|
            val = value.to_s unless value.nil?
            wrapper.add_init_parameter(param.to_s, val)
          end
        end

        def add_servlet_mapping(context, mapping, name)
          if mapping.is_a?(String) || mapping.is_a?(Symbol)
            context.add_servlet_mapping(mapping.to_s, name)
          else
            mapping.each { |m| add_servlet_mapping(context, m, name) }
          end
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