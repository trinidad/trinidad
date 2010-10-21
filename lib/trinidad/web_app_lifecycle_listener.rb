module Trinidad
  class WebAppLifecycleListener
    include Trinidad::Tomcat::LifecycleListener

    attr_reader :context

    def initialize(webapp)
      @webapp = webapp
    end

    def lifecycleEvent(event)
      if Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT == event.type
        init_defaults(event.lifecycle)
      end
    end

    def init_defaults(context)
      @context = context

      deployment_descriptor = configure_deployment_descriptor
      unless deployment_descriptor
        configure_rack_servlet
        configure_rack_listener
      end
      configure_init_params
      configure_context_loader
    end

    def configure_deployment_descriptor
      if descriptor = @webapp.default_deployment_descriptor
        @context.setDefaultWebXml(descriptor)

        context_config = Trinidad::Tomcat::ContextConfig.new
        context_config.setDefaultWebXml(descriptor)

        @context.addLifecycleListener(context_config)
      end
      descriptor
    end

    def configure_rack_servlet
      wrapper = @context.create_wrapper
      wrapper.servlet_class = @webapp.servlet[:class]
      wrapper.name = @webapp.servlet[:name]

      @context.add_child(wrapper)
      @context.add_servlet_mapping('/*', wrapper.name)
    end

    def configure_rack_listener
      @context.addApplicationListener(@webapp.rack_listener)
    end

    def configure_init_params
      @webapp.init_params.each do |name, value|
        @context.addParameter(name, value)
      end
    end

    def configure_context_loader
      class_loader = @webapp.class_loader

      add_application_jars(class_loader)
      add_application_java_classes(class_loader)

      loader = Trinidad::Tomcat::WebappLoader.new(class_loader)
      loader.container = @context
      @context.loader = loader
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
