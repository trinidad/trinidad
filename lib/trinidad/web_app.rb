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
      class_loader = org.jruby.util.JRubyClassLoader.new(JRuby.runtime.jruby_class_loader)
      add_application_libs(class_loader)
      add_application_classes(class_loader)
      
      loader = Trinidad::Tomcat::WebappLoader.new(class_loader)

      loader.container = @context
      @context.loader = loader
    end
    
    def add_init_params
      [:jruby_min_runtimes, :jruby_max_runtimes].each do |param|
        param_name = param.to_s.gsub(/_/, '.')
        @context.addParameter(param_name, @config[param].to_s) unless @context.findParameter(param_name)
      end
      
      @context.addParameter('jruby.initial.runtimes', @config[:jruby_min_runtimes].to_s) unless @context.findParameter('jruby.initial.runtimes')
      @context.addParameter('public.root', File.join('/', public_root)) unless @context.findParameter('public.root')
    end
    
    def add_web_dir_resources
      @context.setDocBase(File.join(@app[:web_app_dir], public_root)) if File.exist?(File.join(@app[:web_app_dir], public_root))
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
  end
end
