module Trinidad
  class WebApp
    attr_reader :context, :config
  
    def self.create(context, config)
      config.has_key?(:rackup) ? RackupWebApp.new(context, config) : RailsWebApp.new(context, config) 
    end
    
    def initialize(context, config)
      @context = context
      @config = config
    end
    
    def add_rack_filter
      unless rack_filter_configured?
        filter_def = Trinidad::Tomcat::FilterDef.new
        filter_def.setFilterName('RackFilter')
        filter_def.setFilterClass('org.jruby.rack.RackFilter')

        pattern = @config[:context_path][-1..-1] != '/' ? @config[:context_path] : @config[:context_path][0..-2]
        filter_map = Trinidad::Tomcat::FilterMap.new
        filter_map.setFilterName('RackFilter')
        filter_map.addURLPattern("#{pattern}/*")

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
      @context.setDocBase(File.join(@config[:web_app_dir], public_root)) if File.exist?(File.join(@config[:web_app_dir], public_root))
    end
    
    def add_rack_context_listener
      unless rack_listener_configured?
        @context.addApplicationListener(context_listener)
      end
    end
    
    def add_application_libs(class_loader)
      resources_dir = File.join(@config[:web_app_dir], @config[:libs_dir], '**', '*.jar')
      
      Dir[resources_dir].each do |resource|
        class_loader.addURL(java.io.File.new(resource).to_url)
      end
    end
    
    def add_application_classes(class_loader)
      resources_dir = File.join(@config[:web_app_dir], @config[:classes_dir])
      class_loader.addURL(java.io.File.new(resources_dir).to_url)
    end

    def load_default_web_xml
      default_web_xml = File.expand_path(File.join(@config[:web_app_dir], @config[:default_web_xml]))
      
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
      @context.findParameter('public.root') || @config[:public] || 'public'
    end
  end
end
