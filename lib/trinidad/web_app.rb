module Trinidad
  class WebApp
    attr_reader :context, :config

    def self.create(context, config, app)
      app.has_key?(:rackup) ? RackupWebApp.new(context, config, app) : RailsWebApp.new(context, config, app)
    end

    def initialize(context, config, app)
      @context = context
      @config = config
      @app = app

      @class_loader = org.jruby.util.JRubyClassLoader.new(JRuby.runtime.jruby_class_loader)
    end

    def configure_rack(servlet_class = 'org.jruby.rack.RackServlet', servlet_name = 'RackServlet')
      unless rack_configured?
        wrapper = @context.createWrapper()
        wrapper.setServletClass(servlet_class)
        wrapper.setName(servlet_name)

        @context.addChild(wrapper)
        @context.addServletMapping('/*', servlet_name)
      end
    end

    def add_context_loader
      add_application_libs(@class_loader)
      add_application_classes(@class_loader)

      loader = Trinidad::Tomcat::WebappLoader.new(@class_loader)

      loader.container = @context
      @context.loader = loader
    end

    def add_init_params
      add_parameter_unless_exist('jruby.min.runtimes', jruby_min_runtimes.to_s)
      add_parameter_unless_exist('jruby.max.runtimes', jruby_max_runtimes.to_s)
      add_parameter_unless_exist('jruby.initial.runtimes', jruby_min_runtimes.to_s)
      add_parameter_unless_exist('public.root', File.join('/', public_root))
    end

    def add_rack_context_listener
      unless rack_listener_configured?
        @context.addApplicationListener(context_listener)
      end
    end

    def add_application_libs(class_loader)
      resources_dir = File.join(@app[:web_app_dir], libs_dir, '**', '*.jar')

      Dir[resources_dir].each do |resource|
        class_loader.addURL(java.io.File.new(resource).to_url)
      end
    end

    def add_application_classes(class_loader)
      resources_dir = File.join(@app[:web_app_dir], classes_dir)
      class_loader.addURL(java.io.File.new(resources_dir).to_url)
    end

    def load_default_web_xml
      file = File.expand_path(File.join(@app[:web_app_dir], default_web_xml))
      file = File.expand_path("../#{provided_web_xml}", __FILE__) unless File.exist?(file)

      @context.setDefaultWebXml(file)

      context_config = Trinidad::Tomcat::ContextConfig.new
      context_config.setDefaultWebXml(file)

      @context.addLifecycleListener(context_config)
    end

    def rack_configured?
      return false if @context.getDefaultWebXml().nil?

      web_xml = IO.read(@context.getDefaultWebXml()).gsub(/\s+/, '')

      return web_xml.include?('<servlet-class>org.jruby.rack.RackServlet') ||
              web_xml.include?('<filter-class>org.jruby.rack.RackFilter')
    end

    def rack_listener_configured?
      return false if @context.getDefaultWebXml().nil?

      web_xml = IO.read(@context.getDefaultWebXml()).gsub(/\s+/, '')

      return web_xml.include?("<listener-class>#{context_listener}")
    end

    def public_root
      @context.findParameter('public.root') || @app[:public]  || @config[:public] || 'public'
    end

    %w{libs_dir classes_dir default_web_xml environment jruby_min_runtimes jruby_max_runtimes}.each do |method_name|
      define_method method_name do
        sym = method_name.to_sym
        @app[sym] || @config[sym]
      end
    end

    def add_parameter_unless_exist(name, value)
      @context.addParameter(name, value) unless @context.findParameter(name)
    end

    def load_extensions?
      @app.has_key?(:extensions)
    end

    def configure_extensions(tomcat)
      return unless load_extensions?

      Trinidad::Extensions.configure_webapp_extensions(@app[:extensions], tomcat, @context)
    end 
  end
end
