module Trinidad
  class WebApp
    attr_reader :config, :app_config, :class_loader, :servlet

    def self.create(config, app_config)
      autodetect_configuration(config, app_config)

      war?(app_config) ? WarWebApp.new(config, app_config) :
        rackup?(app_config) ? RackupWebApp.new(config, app_config) :
          RailsWebApp.new(config, app_config)
    end

    def self.rackup?(app_config)
      app_config[:rackup] || ! Dir['WEB-INF/**/config.ru'].empty?
    end

    def self.war?(app_config)
      app_config[:context_path] && app_config[:context_path][-4..-1] == '.war'
    end

    def initialize(config, app_config, servlet_class = 'org.jruby.rack.RackServlet', servlet_name = 'RackServlet')
      @config, @app_config = config, app_config

      generate_class_loader

      configure_rack_servlet(servlet_class, servlet_name) unless rack_servlet_configured?
    end

    def [](key)
      key = key.to_sym
      @app_config.has_key?(key) ? @app_config[key] : @config[key]
    end
    
    %w{ context_path web_app_dir libs_dir classes_dir default_web_xml async_supported 
        jruby_min_runtimes jruby_max_runtimes rackup log }.each do |method_name|
      class_eval "def #{method_name}; self[:'#{method_name}']; end"
    end

    def public_root; self[:public] || 'public'; end
    def environment; self[:environment] || 'development'; end
    def work_dir; self[:work_dir] || web_app_dir; end
    def log_dir; self[:log_dir] || File.join(work_dir, 'log'); end
    
    def extensions
      @extensions ||= begin
        extensions = @config[:extensions] || {}
        extensions.merge!(@app_config[:extensions]) if @app_config[:extensions]
        extensions
      end
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
      add_parameter_unless_exist 'jruby.compat.version', RUBY_VERSION
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

    def war?; WebApp.war?(app_config); end

    def solo?
      ! is_a?(WarWebApp) && app_config[:solo]
    end

    def threadsafe?
      jruby_min_runtimes.to_i == 1 && jruby_max_runtimes.to_i == 1
    end

    def monitor
      File.expand_path(self[:monitor] || 'tmp/restart.txt', work_dir)
    end

    def generate_class_loader
      @class_loader = org.jruby.util.JRubyClassLoader.new(JRuby.runtime.jruby_class_loader)
    end
    
    def context_listener
      raise NotImplementedError.new "context_listener expected to be redefined in subclass"
    end
    
    def define_lifecycle
      Trinidad::Lifecycle::WebApp::Default.new(self)
    end

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
          logger = java.util.logging.Logger.getLogger('')
          logger.warning "invalid deployment descriptor:[#{default_deployment_descriptor}]\n #{e.message}"
          false
        end unless default_deployment_descriptor.nil?
    end

    def web_context_param(param)
      if web_xml && param = web_xml.root.elements["/web-app/context-param[contains(param-name, '#{param}')]"]
        param.elements['param-value'].text
      end
    end

    def configure_rack_servlet(servlet_class, servlet_name)
      servlet_config = @config[:servlet] || @app_config[:servlet] || {}
      @servlet = {
        :class => servlet_config[:class] || servlet_class,
        :name => servlet_config[:name] || servlet_name,
        :async_supported => !! servlet_config[:async_supported],
        :instance => servlet_config[:instance]
      }
    end

    def self.autodetect_configuration(config, app_config)
      # Check for Rails threadsafe mode
      environment = app_config[:environment] || config[:environment]
      if threadsafe_instance?(app_config[:web_app_dir], environment)
        app_config[:jruby_min_runtimes] = 1
        app_config[:jruby_max_runtimes] = 1
      end
      
      rackup = config[:rackup] || 'config.ru'
      app_config[:web_app_dir] ||= config[:web_app_dir] || Dir.pwd
      # Check for rackup (but still use config/environment.rb for Rails 3)
      if ! app_config[:rackup] &&
          File.exists?(File.join(app_config[:web_app_dir], rackup)) &&
          ! File.exists?(File.join(app_config[:web_app_dir], 'config/environment.rb'))
        app_config[:rackup] = rackup
      end
    end

    def self.threadsafe_instance?(app_base, environment)
      threadsafe_match?("#{app_base}/config/environments/#{environment}.rb") ||
        threadsafe_match?("#{app_base}/config/environment.rb")
    end

    def self.threadsafe_match?(file)
      File.exist?(file) && File.readlines(file).any? { |l| l =~ /^[^#]*threadsafe!/ }
    end
    
    class Holder
      
      def initialize(web_app, context)
        @web_app, @context = web_app, context
      end
      
      attr_reader :web_app
      attr_accessor :context
      
      def monitor
        web_app.monitor
      end
      
      attr_accessor :monitor_mtime
      
      def try_lock
        locked? ? false : lock
      end

      def locked?; !!@lock; end
      def lock; @lock = true; end
      def unlock; @lock = false;end
      
      # #deprecated behave Hash like for (<= 1.3.5) compatibility
      def [](key)
        case key.to_sym
          when :app then
            web_app
          when :context then
            context
          when :lock then
            @lock
          when :monitor then
            monitor
          when :mtime then
            monitor_mtime
          else raise NoMethodError, key.to_s
        end
      end

      # #deprecated behave Hash like for (<= 1.3.5) compatibility
      def []=(key, val)
        case key.to_sym
          when :context then
            self.context=(val)
          when :lock then
            @lock = val
          when :mtime then
            self.monitor_mtime=(val)
          else raise NoMethodError, "#{key}="
        end
      end
      
    end
    
  end
end
