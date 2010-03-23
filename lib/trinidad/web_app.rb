module Trinidad
  class WebApp
    include Trinidad::Extensions

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

    def add_rack_filter
      unless rack_filter_configured?
        filter_def = Trinidad::Tomcat::FilterDef.new
        filter_def.setFilterName('RackFilter')
        filter_def.setFilterClass('org.jruby.rack.RackFilter')

        filter_map = Trinidad::Tomcat::FilterMap.new
        filter_map.setFilterName('RackFilter')
        filter_map.addURLPattern('/*')

        @context.addFilterDef(filter_def)
        @context.addFilterMap(filter_map)
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
      [:jruby_min_runtimes, :jruby_max_runtimes].each do |param|
        param_name = param.to_s.gsub(/_/, '.')
        add_parameter_unless_exist(param_name, @config[param].to_s)
      end

      add_parameter_unless_exist('jruby.initial.runtimes', @config[:jruby_min_runtimes].to_s)
      add_parameter_unless_exist('public.root', File.join('/', public_root))
    end

    def add_web_dir_resources
      doc_base = File.join(@app[:web_app_dir], public_root)
      @context.setDocBase(doc_base) if File.exist?(doc_base)
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
      default_web_xml = File.expand_path(File.join(@app[:web_app_dir], default_web_xml_file))

      if File.exist?(default_web_xml)
        @context.setDefaultWebXml(default_web_xml)
        @context.setDefaultContextXml(default_web_xml)

        context_config = Trinidad::Tomcat::ContextConfig.new
        context_config.setDefaultWebXml(default_web_xml)

        @context.addLifecycleListener(context_config)
      end
    end

    def rack_filter_configured?
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

    def libs_dir
      @app[:libs_dir] || @config[:libs_dir]
    end

    def classes_dir
      @app[:classes_dir] || @config[:classes_dir]
    end

    def default_web_xml_file
      @app[:default_web_xml] || @config[:default_web_xml]
    end

    def environment
      @app[:environment] || @config[:environment]
    end

    def add_parameter_unless_exist(name, value)
      @context.addParameter(name, value) unless @context.findParameter(name)
    end

    def load_extensions?
      @app.has_key?(:extensions)
    end

    def configure_extensions
      return unless load_extensions?

      @app[:extensions].each do |name, options|
        configure_extension_by_name_and_type(name, :webapp, @context, @class_loader, options)
      end
    end
  end
end
