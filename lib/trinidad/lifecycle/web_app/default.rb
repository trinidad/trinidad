require 'trinidad/lifecycle/base'
require 'trinidad/lifecycle/web_app/shared'

module Trinidad
  module Lifecycle
    module WebApp
      class Default < Lifecycle::Base
        include Shared

        def configure(context)
          super
          deployment_descriptor = configure_deployment_descriptor(context)
          unless deployment_descriptor
            configure_rack_servlet(context)
            configure_rack_listener(context)
          end
          configure_context_loader(context)
          configure_context_params(context)
        end

        def before_init(event)
          super
          set_context_xml event.lifecycle
          # AFTER_INIT_EVENT ContextConfig#init() will pick this up
        end

        def before_start(event)
          super
          # on CONFIGURE_START context.jar_scanner is used
          set_jar_scanner event.lifecycle
        end

        protected

        @@_add_context_config = true # due backward compatibility

        def configure_deployment_descriptor(context)
          descriptor = web_app.deployment_descriptor
          if descriptor && File.exist?(descriptor)
            listeners = context.find_lifecycle_listeners
            context_config = listeners && listeners.find do |listener|
              listener.is_a?(Trinidad::Tomcat::ContextConfig)
            end

            if context_config.nil?
              if @@_add_context_config
                context_config = Trinidad::Tomcat::ContextConfig.new
                context.add_lifecycle_listener(context_config)
              else
                raise "initialized context is missing a ContextConfig listener"
              end
            end

            context_config.setDefaultWebXml(descriptor)
            descriptor
          end
        end

        def configure_rack_servlet(context)
          wrapper = context.create_wrapper
          rack_servlet = web_app.rack_servlet
          if rack_servlet[:instance]
            wrapper.servlet = rack_servlet[:instance]
            web_app[:add_jruby_rack_jar] = false
          else
            wrapper.servlet_class = rack_servlet[:class]
            wrapper.async_supported = rack_servlet[:async_supported]
            wrapper.load_on_startup = rack_servlet[:load_on_startup]
            add_init_params wrapper, rack_servlet[:init_params]
          end
          name = wrapper.name = rack_servlet[:name]

          context.add_child(wrapper)
          add_servlet_mapping(context, rack_servlet[:mapping], name)
        end

        def configure_rack_listener(context)
          unless web_app.rack_servlet[:instance]
            if rack_listener = web_app.rack_listener
              context.add_application_listener(rack_listener)
            end
          end
        end

        def configure_context_params(context)
          web_app.context_params.each do |name, value|
            context.add_parameter(name, value)
          end
        end
        # @deprecated use {#configure_context_params}
        alias_method :configure_init_params, :configure_context_params

        def configure_context_loader(context)
          loader = new_context_loader
          add_jruby_rack_jar(loader)
          add_application_java_classes(loader)
          add_application_jars(loader) # classes takes precedence !

          context.loader = loader # does loader.container = context
        end

        def add_jruby_rack_jar(loader)
          return if web_app[:add_jruby_rack_jar] == false
          if jruby_rack_jar = JRUBY_RACK_JAR_PATH
            logger.debug "[#{web_app.context_path}] adding jar: #{jruby_rack_jar}"
            loader.addRepository to_url_path(jruby_rack_jar)
          end
        end

        def add_application_jars(loader)
          return unless lib_dir = web_app.java_lib_dir
          # loader.setJarPath(lib_dir) no point since startInternal re-sets it
          Dir[ File.join(lib_dir, "**/*.jar") ].each do |jar|
            logger.debug "[#{web_app.context_path}] adding jar: #{jar}"
            loader.addRepository to_url_path(jar)
          end
        end

        def add_application_java_classes(loader)
          return unless classes_dir = web_app.java_classes_dir
          logger.debug "[#{web_app.context_path}] adding dir: #{classes_dir}"
          loader.addRepository to_url_path(classes_dir)
        end

        def set_jar_scanner(context)
          context.setJarScanner Java::RbTrinidadContext::DefaultJarScanner.new(context)
        end

        def set_context_xml(context)
          # behave similar to a .war - checking /META-INF/context.xml on CP
          context_xml = web_app.context_xml
          context_xml = 'META-INF/context.xml' if context_xml.nil?
          if context_xml
            # NOTE: make it absolute to ContextConfig to not use a baseDir :
            unless java.io.File.new(context_xml).absolute?
              if web_app.java_classes_dir
                context_xml = File.join(web_app.java_classes_dir, context_xml)
              else
                context_xml = File.expand_path(context_xml, web_app.root_dir)
              end
            end
            context.setDefaultContextXml(context_xml)
          end
        end

        private

        def new_context_loader
          class_loader = JRuby.runtime.jruby_class_loader
          Java::RbTrinidadContext::DefaultLoader.new(class_loader)
        end

        def to_url_path(path); Helpers.to_url(path).to_s end

      end
    end
    Default = Trinidad::Lifecycle::WebApp::Default # backwards compatibility
  end
end
