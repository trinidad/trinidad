module Trinidad
  class WebApp
    attr_reader :config, :app_config, :class_loader, :servlet

    def self.create(config, app_config)
      war?(app_config) ? WarWebApp.new(config, app_config) :
        rackup?(app_config) ? RackupWebApp.new(config, app_config) : RailsWebApp.new(config, app_config)
    end

    def self.rackup?(app_config)
      app_config.has_key?(:rackup) || !Dir['WEB-INF/**/config.ru'].empty?
    end

    def self.war?(app_config)
      app_config[:context_path] =~ /\.war$/
    end

    def initialize(config, app_config, servlet_class = 'org.jruby.rack.RackServlet', servlet_name = 'RackServlet')
      @config = config
      @app_config = app_config

      @class_loader = org.jruby.util.JRubyClassLoader.new(JRuby.runtime.jruby_class_loader)

      configure_rack_servlet(servlet_class, servlet_name) unless rack_servlet_configured?
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
        file = File.expand_path(File.join(work_dir, default_web_xml))
        File.exist?(file) ? file : nil
      end
    end

    def rack_servlet_configured?
      !!( web_xml && (
          web_xml.root.elements["/web-app/servlet[contains(servlet-class, 'org.jruby.rack.RackServlet')]"] ||
          web_xml.root.elements["/web-app/filter[contains(filter-class, 'org.jruby.rack.RackFilter')]"]
        )
      )
    end

    def rack_listener_configured?
      !!( web_xml &&
          web_xml.root.elements["/web-app/listener[contains(listener-class, '#{context_listener}')]"]
      )
    end

    def public_root
      @app_config[:public]  || @config[:public] || 'public'
    end

    %w{context_path web_app_dir libs_dir classes_dir default_web_xml environment
        jruby_min_runtimes jruby_max_runtimes rackup log}.each do |method_name|
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

    def war?; WebApp.war?(app_config); end
    def work_dir; web_app_dir; end

    protected
    def add_parameter_unless_exist(param_name, param_value)
      @params[param_name] = param_value unless web_context_param(param_name)
    end

    private
    def web_xml
      return nil if @web_xml == false
      @web_xml ||=
        begin
          require 'rexml/document'
          REXML::Document.new(File.read(default_deployment_descriptor))
        rescue REXML::ParseException => e
          puts "WARNING: invalid deployment descriptor:[#{default_deployment_descriptor}]"
          puts e.message
          false
        end unless default_deployment_descriptor.nil?
    end

    def web_context_param(param)
      if web_xml && param = web_xml.root.elements["/web-app/context-param[contains(param-name, '#{param}')]"]
        param.elements['param-value'].text
      end
    end

    def configure_rack_servlet(servlet_class, servlet_name)
      servlet_config = @config[:servlet] || @app_config[:servlet]
      if servlet_config
        servlet_class = servlet_config[:class]
        servlet_name = servlet_config[:name]
      end
      @servlet = {:class => servlet_class, :name => servlet_name}
    end
  end
end
