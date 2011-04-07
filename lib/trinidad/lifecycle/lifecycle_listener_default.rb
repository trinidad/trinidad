module Trinidad
  module Lifecycle
    class Default < Base
      def configure_defaults(context)
        super
        deployment_descriptor = configure_deployment_descriptor(context)
        unless deployment_descriptor
          configure_rack_servlet(context)
          configure_rack_listener(context)
        end
        configure_init_params(context)
        configure_context_loader(context)
      end

      def configure_deployment_descriptor(context)
        if descriptor = @webapp.default_deployment_descriptor
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
        wrapper.servlet_class = @webapp.servlet[:class]
        wrapper.name = @webapp.servlet[:name]

        context.add_child(wrapper)
        context.add_servlet_mapping('/*', wrapper.name)
      end

      def configure_rack_listener(context)
        context.addApplicationListener(@webapp.rack_listener)
      end

      def configure_init_params(context)
        @webapp.init_params.each do |name, value|
          context.addParameter(name, value)
        end
      end

      def configure_context_loader(context)
        class_loader = @webapp.class_loader

        add_application_jars(class_loader)
        add_application_java_classes(class_loader)

        loader = Trinidad::Tomcat::WebappLoader.new(class_loader)
        loader.container = context
        context.loader = loader
      end

      def add_application_jars(class_loader)
        return unless @webapp.libs_dir

        resources_dir = File.join(@webapp.web_app_dir, @webapp.libs_dir, '**', '*.jar')

        Dir[resources_dir].each do |resource|
          class_loader.addURL(java.io.File.new(resource).to_url)
        end
      end

      def add_application_java_classes(class_loader)
        return unless @webapp.classes_dir

        resources_dir = File.join(@webapp.web_app_dir, @webapp.classes_dir)
        class_loader.addURL(java.io.File.new(resources_dir).to_url)
      end
    end
  end
end
