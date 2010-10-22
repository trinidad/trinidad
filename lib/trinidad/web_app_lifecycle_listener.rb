module Trinidad
  class WebAppLifecycleListener
    include Trinidad::Tomcat::LifecycleListener

    attr_reader :context

    def initialize(webapp)
      @webapp = webapp
      @configured_logger = false
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
      configure_logging
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

    def configure_logging
      return if @configured_logger

      log_path = File.join(@webapp.web_app_dir, 'log', "#{@webapp.environment}.log")
      log_file = java.io.File.new(log_path)

      unless log_file.exists
        log_file.parent_file.mkdirs
        log_file.create_new_file
      end

      jlogging = java.util.logging

      log_handler = jlogging.FileHandler.new(log_path, true)
      logger = jlogging.Logger.get_logger("")

      log_level = @webapp.log
      unless %w{ALL CONFIG FINE FINER FINEST INFO OFF SEVERE WARNING}.include?(log_level)
        puts "Invalid log level #{log_level}, using default: INFO"
        log_level = 'INFO'
      end

      level = jlogging.Level.parse(log_level)

      logger.handlers.each do |handler|
        handler.level = level
      end

      logger.level = level

      log_handler.formatter = jlogging.SimpleFormatter.new
      logger.add_handler(log_handler)

      @configured_logger = true
    end
  end
end
