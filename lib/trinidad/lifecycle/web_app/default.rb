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
          configure_context_params(context)
          configure_context_loader(context)
        end

        protected
        
        def configure_deployment_descriptor(context)
          if descriptor = web_app.deployment_descriptor
            listeners = context.findLifecycleListeners
            context_config = listeners && listeners.find do |listener|
              listener.is_a?(Trinidad::Tomcat::ContextConfig)
            end

            unless context_config
              context_config = Trinidad::Tomcat::ContextConfig.new
              context.addLifecycleListener(context_config)
            end

            context_config.setDefaultWebXml(descriptor)
          end
          descriptor
        end

        def configure_rack_servlet(context)
          wrapper = context.create_wrapper
          if web_app.rack_servlet[:instance]
            wrapper.servlet = web_app.rack_servlet[:instance]
          else
            wrapper.servlet_class = web_app.rack_servlet[:class]
            wrapper.async_supported = web_app.rack_servlet[:async_supported]
          end
          wrapper.name = web_app.rack_servlet[:name]

          context.add_child(wrapper)
          context.add_servlet_mapping('/*', wrapper.name)
        end

        def configure_rack_listener(context)
          context.addApplicationListener(web_app.rack_listener) unless web_app.rack_servlet[:instance]
        end

        def configure_context_params(context)
          web_app.context_params.each do |name, value|
            context.addParameter(name, value)
          end
        end
        # @deprecated use {#configure_context_params}
        alias_method :configure_init_params, :configure_context_params

        def configure_context_loader(context)
          class_loader = web_app.class_loader

          add_application_jars(class_loader)
          add_application_java_classes(class_loader)

          loader = Trinidad::Tomcat::WebappLoader.new(class_loader)
          context.loader = loader # does loader.container = context
        end

        def add_application_jars(class_loader)
          return unless web_app.libs_dir

          resources_dir = File.join(web_app.web_app_dir, web_app.libs_dir, '**', '*.jar')

          Dir[resources_dir].each do |resource|
            class_loader.addURL(java.io.File.new(resource).to_url)
          end
        end

        def add_application_java_classes(class_loader)
          return unless web_app.classes_dir

          resources_dir = File.join(web_app.web_app_dir, web_app.classes_dir)
          class_loader.addURL(java.io.File.new(resources_dir).to_url)
        end
        
      end
    end
    Default = Trinidad::Lifecycle::WebApp::Default # backwards compatibility
  end
end
