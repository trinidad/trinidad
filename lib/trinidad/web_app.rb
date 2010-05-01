module Trinidad
  class WebApp
    attr_reader :config, :app_config, :class_loader, :servlet

    def self.create(config, app_config)
      app_config.has_key?(:rackup) ? RackupWebApp.new(config, app_config) : RailsWebApp.new(config, app_config)
    end

    def initialize(config, app_config, servlet_class = 'org.jruby.rack.RackServlet', servlet_name = 'RackServlet')
      @config = config
      @app_config = app_config

      @class_loader = org.jruby.util.JRubyClassLoader.new(JRuby.runtime.jruby_class_loader)
      @servlet = {:class => servlet_class, :name => servlet_name} unless rack_servlet_configured?
    end

    def rack_listener
      context_listener unless rack_listener_configured?
    end

    def init_params
      @params ||= {}
      add_parameter_unless_exist 'jruby.min.runtimes', jruby_min_runtimes.to_s
      add_parameter_unless_exist 'jruby.max.runtimes', jruby_max_runtimes.to_s
      add_parameter_unless_exist 'jruby.initial.runtimes', jruby_min_runtimes.to_s
      add_parameter_unless_exist 'public.root', File.join('/', public_root)
      @params
    end

    def default_deployment_descriptor
      @deployment_descriptor ||= if default_web_xml
        file = File.expand_path(File.join(web_app_dir, default_web_xml))
        File.exist?(file) ? file : nil
      end
    end

    def rack_servlet_configured?
      web_xml && (web_xml.include?('<servlet-class>org.jruby.rack.RackServlet') ||
        web_xml.include?('<filter-class>org.jruby.rack.RackFilter'))
    end

    def rack_listener_configured?
      web_xml && web_xml.include?("<listener-class>#{context_listener}")
    end

    def public_root
      @app_config[:public]  || @config[:public] || 'public'
    end

    %w{web_app_dir libs_dir classes_dir default_web_xml environment jruby_min_runtimes jruby_max_runtimes rackup}.each do |method_name|
      define_method method_name do
        sym = method_name.to_sym
        @app_config[sym] || @config[sym]
      end
    end

    def extensions
      @extensions ||= begin
        extensions = @config[:extensions] || {}
        extensions.merge!(@app_config[:extensions]) if @app_config[:extensions]
        extensions
      end
    end

    protected
    def add_parameter_unless_exist(param_name, param_value)
      @params[param_name] = param_value unless web_context_param(param_name)
    end

    private
    def web_xml
      @web_xml ||= File.read(default_deployment_descriptor).gsub(/\s+/, '') unless default_deployment_descriptor.nil?
    end

    def web_context_param(param)
      if web_xml =~ /<context-param><param-name>#{param}<\/param-name><param-value>(.+)<\/param-value>/
        return $1
      end
    end
  end
end
