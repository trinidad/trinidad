module Trinidad
  class WebApp
    
    attr_reader :config, :default_config

    def self.create(config, default_config = Trinidad.configuration)
      war?(config, default_config) ? WarWebApp.new(config, default_config) :
        rackup?(config, default_config) ? RackupWebApp.new(config, default_config) :
          RailsWebApp.new(config, default_config)
    end

    def initialize(config, default_config)
      @config, @default_config = config, default_config || {}
      complete_config!
      # NOTE: we should maybe @config.freeze here ?!
    end

    def [](key)
      key = key.to_sym
      config.has_key?(key) ? config[key] : default_config[key]
    end
    
    %w{ context_path root_dir libs_dir classes_dir
        jruby_min_runtimes jruby_max_runtimes jruby_compat_version
        rackup log async_supported reload_strategy }.each do |method|
      class_eval "def #{method}; self[:'#{method}']; end"
    end
    
    def web_xml; self[:web_xml] || self[:default_web_xml]; end
    def default_web_xml; self[:default_web_xml]; end
    def context_xml; self[:context_xml] || self[:default_context_xml]; end
    
    def public_root; self[:public] || 'public'; end
    def environment; self[:environment] || 'development'; end
    alias_method :web_app_dir, :root_dir # is getting deprecated soon
    
    # by a "Rails" convention defaults to '[RAILS_ROOT]/log'
    def log_dir
      @log_dir ||= self[:log_dir] || File.join(root_dir, 'log')
    end
    
    # by (a "Rails") convention use '[RAILS_ROOT]/tmp'
    def work_dir
      @work_dir ||= self[:work_dir] || File.join(root_dir, 'tmp')
    end
    
    def monitor
      File.expand_path(self[:monitor] || 'restart.txt', work_dir)
    end
    
    def extensions
      @extensions ||= begin
        extensions = default_config[:extensions] || {}
        extensions.merge(config[:extensions] || {})
      end
    end

    def context_params
      @context_params ||= {}
      add_context_param 'jruby.min.runtimes', jruby_min_runtimes
      add_context_param 'jruby.max.runtimes', jruby_max_runtimes
      add_context_param 'jruby.initial.runtimes', jruby_min_runtimes
      add_context_param 'jruby.compat.version', jruby_compat_version || RUBY_VERSION
      add_context_param 'public.root', File.join('/', public_root)
      @context_params
    end
    # @deprecated replaced with {#context_params}
    def init_params; context_params; end

    def add_context_param(param_name, param_value)
      @context_params ||= {}
      if ! param_value.nil? && ! web_xml_context_param(param_name)
        @context_params[param_name] = param_value.to_s
      end
    end

    def deployment_descriptor
      @deployment_descriptor ||= if web_xml
        # absolute ?
        file = File.expand_path(File.join(root_dir, web_xml))
        File.exist?(file) ? file : nil
      end
    end
    
    # @deprecated use {#deployment_descriptor}
    def default_deployment_descriptor
      @default_deployment_descriptor ||= if default_web_xml
        file = File.expand_path(File.join(root_dir, default_web_xml))
        File.exist?(file) ? file : nil
      end
    end
    
    def class_loader
      @class_loader ||= org.jruby.util.JRubyClassLoader.new(JRuby.runtime.jruby_class_loader)
    end
    
    def class_loader!
      ( @class_loader = nil ) || class_loader
    end
    # @deprecated replaced with {#class_loader!}
    def generate_class_loader; class_loader!; end
    
    def define_lifecycle
      Trinidad::Lifecycle::WebApp::Default.new(self)
    end

    # Reset the hold web application state so it gets re-initialized.
    # Please note that the configuration objects are not cleared.
    def reset!
      vars = instance_variables.map(&:to_sym) 
      vars = vars - [ :'@config', :'@default_config' ]
      vars.each { |var| instance_variable_set(var, nil) }
    end
    
    DEFAULT_SERVLET_CLASS = nil # by default we resolve by it's name
    DEFAULT_SERVLET_NAME = 'default'
    
    # Returns a servlet config for the DefaultServlet. 
    # This servlet is setup for each and every Tomcat context and is named 
    # 'default' and mapped to '/' we allow fine tunning of this servlet.
    # Return values should be interpreted as follows :
    #  true - do nothing leave the servlet as set-up (by default)
    #  false - remove the set-up default (e.g. configured in web.xml)
    def default_servlet
      return @default_servlet unless @default_servlet.nil?
      @default_servlet ||= begin
        if ! web_xml_servlet?(nil, DEFAULT_SERVLET_NAME)
          default_servlet = self[:default_servlet]
          if default_servlet.is_a?(javax.servlet.Servlet)
            { :instance => default_servlet }
          else
            default_servlet || true
          end
        else
          false # configured in web.xml thus remove the (default) "default"
        end
      end
    end
    
    RACK_SERVLET_CLASS = 'org.jruby.rack.RackServlet'
    RACK_SERVLET_NAME = 'RackServlet' # in-case of a "custom" RackServlet class
    RACK_FILTER_CLASS = 'org.jruby.rack.RackFilter'
    
    # Returns a config for the RackServlet or nil if no need to set-up one.
    # (to be used for dispatching to this Rack / Rails web application)
    def rack_servlet
      return nil if @rack_servlet == false
      @rack_servlet ||= begin
        rack_servlet = self[:rack_servlet] || self[:servlet] || {}
        
        if rack_servlet.is_a?(javax.servlet.Servlet)
          { :instance => rack_servlet, :name => RACK_SERVLET_NAME, :mapping => '/*' }
        else
          servlet_class = rack_servlet[:class] || RACK_SERVLET_CLASS
          servlet_name = rack_servlet[:name] || RACK_SERVLET_NAME
          
          if ! web_xml_servlet?(servlet_class, servlet_name) &&
              ! web_xml_filter?(RACK_FILTER_CLASS)
            {
              :instance => rack_servlet[:instance],
              :class => servlet_class, :name => servlet_name,
              :init_params => rack_servlet[:init_params],
              :async_supported => !! ( rack_servlet.has_key?(:async_supported) ?
                  rack_servlet[:async_supported] : async_supported ),
              :load_on_startup => ( rack_servlet[:load_on_startup] || 2 ).to_i,
              :mapping => rack_servlet[:mapping] || '/*'
            }
          else
            if ! rack_servlet.empty?
              logger.info "ignoring :rack_servlet configuration for " +
                          "#{context_path} due #{deployment_descriptor}"
            end
            false # no need to setup a rack servlet
          end
        end
      end || nil
    end
    # @deprecated use {#rack_servlet} instead
    def servlet; rack_servlet; end
    
    def rack_listener
      context_listener unless web_xml_listener?(context_listener)
    end
    
    def war?; self.class.war?(config); end

    def solo?
      ! is_a?(WarWebApp) && config[:solo]
    end

    def threadsafe?
      jruby_min_runtimes.to_i == 1 && jruby_max_runtimes.to_i == 1
    end
    
    protected
    
    def context_listener
      raise NotImplementedError.new "context_listener expected to be redefined"
    end
    
    def complete_config!
      config[:root_dir] ||= self.class.root_dir(config, default_config)
    end
    
    public
    
    # Returns true if there's a servlet with the given servlet-class name 
    # configured or if the optional name second argument is given it also
    # checks for a servlet with the given name.
    def web_xml_servlet?(servlet_class, servlet_name = nil)
      return nil unless web_xml_doc
      if servlet_class
        servlet_xpath = "/web-app/servlet[servlet-class = '#{servlet_class}']"  
        return true if web_xml_doc.root.elements[servlet_xpath] # else try name
      end
      if servlet_name
        servlet_xpath = "/web-app/servlet[servlet-name = '#{servlet_name}']"
        return !! web_xml_doc.root.elements[servlet_xpath]
      end
      
      return false if servlet_class || servlet_name
      raise ArgumentError, "nor servlet_class nor servlet_name given"
    end

    # Returns true if a filter definition with a given filter-class is found.
    def web_xml_filter?(filter_class)
      return nil unless web_xml_doc
      !! web_xml_doc.root.elements["/web-app/filter[filter-class = '#{filter_class}']"]
    end
    
    # Returns true if a listener definition with a given listener-class is found.
    def web_xml_listener?(listener_class)
      return nil unless web_xml_doc
      !! web_xml_doc.root.elements["/web-app/listener[listener-class = '#{listener_class}']"]
    end
    
    # Returns a param-value for a context-param with a given param-name.
    def web_xml_context_param(name)
      return nil unless web_xml_doc
      if param = web_xml_doc.root.elements["/web-app/context-param[param-name = '#{name}']"]
        param.elements['param-value'].text
      end
    end
    
    private
    
    def web_xml_doc
      return @web_xml_doc || nil unless @web_xml_doc.nil?
      if deployment_descriptor
        begin
          require 'rexml/document'
          @web_xml_doc = REXML::Document.new(File.read(deployment_descriptor))
        rescue REXML::ParseException => e
          logger.warn "invalid deployment descriptor:[#{deployment_descriptor}]\n #{e.message}"
          @web_xml_doc = false
        end
        @web_xml_doc || nil
      end
    end
    
    def logger
      @logger ||= Trinidad::Logging::LogFactory.getLog('')
    end
    
    protected
    
    def self.rackup?(config, default_config = nil)
      return true if config.has_key?(:rackup)
      root_dir = root_dir(config, default_config)
      config_ru = (default_config && default_config[:rackup]) || 'config.ru'
      # check for rackup (but still use config/environment.rb for rails 3)
      if File.exists?(File.join(root_dir, config_ru)) && 
          ! rails?(config, default_config) # do not :rackup a rails app
        config[:rackup] = config_ru
      end
      config[:rackup] || ! Dir[File.join(root_dir, 'WEB-INF/**/config.ru')].empty?
    end
    
    def self.rails?(config, default_config = nil)
      root_dir = root_dir(config, default_config)
      # standart Rails 3.x `class Application < Rails::Application`
      if File.exists?(application = File.join(root_dir, 'config/application.rb'))
        return true if file_line_match?(application, /^[^#]*Rails::Application/)
      end
      if File.exists?(environment = File.join(root_dir, 'config/environment.rb'))
        return true if file_line_match?(environment) do |line|
          # customized Rails 3.x, expects a `Rails::Application` subclass
          # or a plain-old Rails 2.3 with `RAILS_GEM_VERSION = '2.3.14'`
          line =~ /^[^#]*Rails::Application/ || line =~ /^[^#]*RAILS_GEM_VERSION/
        end
      end
      false
    end
    
    def self.war?(config, default_config = nil)
      config[:context_path] && config[:context_path][-4..-1] == '.war'
    end
    
    private
    
    def self.root_dir(config, default_config)
      # for backwards compatibility accepts the :web_app_dir "alias"
      config[:root_dir] || config[:web_app_dir] || 
        ( default_config && 
          ( default_config[:root_dir] || default_config[:web_app_dir] ) ) ||
            Dir.pwd
    end
    
    def self.file_line_match?(path, pattern = nil)
      File.open(path) do |file|
        if block_given?
          file.each_line { |line| return true if yield(line) }
        else
          file.each_line { |line| return true if line =~ pattern }
        end
      end
      false
    end
    
    class Holder
      
      def initialize(web_app, context)
        @web_app, @context = web_app, context
      end
      
      attr_reader :web_app
      attr_accessor :context
      
      def monitor; web_app.monitor; end
      
      attr_accessor :monitor_mtime
      
      def try_lock
        locked? ? false : lock
      end

      def locked?; !!@lock; end
      def lock; @lock = true; end
      def unlock; @lock = false; end
      
      # @deprecated behaves Hash like for (<= 1.3.5) compatibility
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

      # @deprecated behaves Hash like for (<= 1.3.5) compatibility
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
  
  # Rack web application (looks for a rackup config.ru file).
  class RackupWebApp < WebApp

    def context_params
      add_context_param 'rack.env', environment
      if rackup = self.rackup
        rackup = File.join(rackup, 'config.ru') if File.directory?(rackup)
        add_context_param 'rackup.path', rackup
      end
      super
    end

    def context_listener; 'org.jruby.rack.RackServletContextListener'; end
    
  end
  
  # Rails web app specifics. Supports the same versions as jruby-rack !
  class RailsWebApp < WebApp

    def context_params
      add_context_param 'rails.env', environment
      add_context_param 'rails.root', '/'
      super
    end

    def context_listener; 'org.jruby.rack.rails.RailsServletContextListener'; end
    
    protected
    
    def complete_config!
      super
      # detect threadsafe! in config/environments/environment.rb :
      if self.class.threadsafe?(root_dir, environment)
        config[:jruby_min_runtimes] = 1
        config[:jruby_max_runtimes] = 1
      end
    end
    
    private
    
    def self.threadsafe?(app_base, environment)
      threadsafe_match?("#{app_base}/config/environments/#{environment}.rb") ||
        threadsafe_match?("#{app_base}/config/environment.rb")
    end

    def self.threadsafe_match?(file)
      File.exist?(file) && file_line_match?(file, /^[^#]*threadsafe!/)
    end
    
  end
  
  # A web application for deploying (java) .war files.
  class WarWebApp < WebApp
    
    def context_path
      super.gsub(/\.war$/, '')
    end

    def log_dir
      @log_dir ||= self[:log_dir] || File.join(work_dir, 'log')
    end
    
    def work_dir
      @work_dir ||= File.join(root_dir.gsub(/\.war$/, ''), 'WEB-INF')
    end

    def monitor
      File.expand_path(root_dir)
    end

    def define_lifecycle
      Trinidad::Lifecycle::WebApp::War.new(self)
    end
    
  end
  
end
