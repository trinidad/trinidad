require 'trinidad/configuration'

module Trinidad
  class WebApp

    @@defaults = Configuration::DEFAULTS

    attr_reader :config, :default_config

    def self.create(config, default_config = Trinidad.configuration)
      war?(config, default_config) ? WarWebApp.new(config, default_config) :
        rackup?(config, default_config) ? RackupWebApp.new(config, default_config) :
          RailsWebApp.new(config, default_config)
    end

    def initialize(config, default_config = Trinidad.configuration)
      @config, @default_config = config, default_config || {}
      complete_config!
      # NOTE: we should maybe @config.freeze here ?!
    end

    def [](key)
      key = key.to_sym
      config.key?(key) ? config[key] : default_config[key]
    end

    def []=(key, value)
      config[key.to_sym] = value
    end

    def key?(key, use_default = true)
      key = key.to_sym
      return true if config.has_key?(key)
      use_default ? default_config.key?(key) : false
    end

    def root_dir; self[:root_dir] end
    def rackup; self[:rackup] end
    def host_name; self[:host_name] end
    def async_supported; self[:async_supported] end
    def reload_strategy; self[:reload_strategy] end

    alias_method :web_app_dir, :root_dir # is getting deprecated soon
    def app_root; root_dir; end

    # @deprecated use `self[:log]` instead
    def log; self[:log]; end

    def context_path
      path = self[:context_path] || self[:path]
      path ? path.to_s : path #
    end

    def context_name
      name = self[:context_name] || self[:name]
      name ? name.to_s : name
    end

    # NOTE: should be set to application root (base) directory thus
    # JRuby-Rack correctly resolves relative paths for the context!
    def doc_base; self[:doc_base] || root_dir; end

    def allow_linking; key?(:allow_linking) ? self[:allow_linking] : true; end

    def jruby_min_runtimes
      if min = config[:jruby_min_runtimes]
        return min.to_i # min specified overrides :threadsafe
      else # but :threadsafe takes precedence over default
        # (if no default value specified we'll end up thread-safe) :
        self[:threadsafe] ? 1 : fetch_default_config_value(:jruby_min_runtimes, 1)
      end
    end

    def jruby_max_runtimes
      if max = config[:jruby_max_runtimes]
        return max.to_i # max specified overrides :threadsafe
      else # but :threadsafe takes precedence over default
        # (if no default value specified we'll end up thread-safe) :
        self[:threadsafe] ? 1 : fetch_default_config_value(:jruby_max_runtimes, 1)
      end
    end

    def jruby_initial_runtimes
      if ini = config[:jruby_initial_runtimes]
        return ini.to_i # min specified overrides :threadsafe
      else # but :threadsafe takes precedence over default :
        self[:threadsafe] ? 1 :
          fetch_default_config_value(:jruby_initial_runtimes, jruby_min_runtimes)
      end
    end

    def jruby_runtime_acquire_timeout
      fetch_config_value(:jruby_runtime_acquire_timeout, 5.0) # default 10s seems too high
    end

    def jruby_compat_version
      compat_version = fetch_config_value(:jruby_compat_version, false)
      return compat_version unless compat_version.eql? false
      JRUBY_VERSION < '9.0' ? RUBY_VERSION[0, 3] : nil
    end

    def environment
      @environment ||= begin
        if env = web_xml_environment
          if self[:environment] && env != self[:environment]
            logger.info "Ignoring set :environment '#{self[:environment]}' for " <<
              "#{context_path} since it's configured in web.xml as '#{env}'"
          end
        else
          env = self[:environment] || @@defaults[:environment]
          env = env.to_s if env.is_a?(Symbol) # make sure it's a String
        end
        env
      end
    end

    def public_dir
      @public_dir ||= ( public_root == '/' ? root_dir : expand_path(public_root) )
    end

    # by (a "Rails") convention use '[RAILS_ROOT]/tmp'
    def work_dir
      @work_dir ||= self[:work_dir] || File.join(root_dir, 'tmp')
    end

    # by a "Rails" convention defaults to '[RAILS_ROOT]/log'
    def log_dir
      @log_dir ||= self[:log_dir] || File.join(root_dir, 'log')
    end

    def monitor
      File.expand_path(self[:monitor] || 'restart.txt', work_dir)
    end

    def context_xml; self[:context_xml] || self[:default_context_xml]; end
    def web_xml; self[:web_xml] || self[:default_web_xml]; end
    def default_web_xml; self[:default_web_xml]; end

    def java_lib
      self[:java_lib] || begin
        if libs_dir = self[:libs_dir] # @deprecated
          Helpers.deprecate "please use :java_lib instead of :libs_dir"
        end
        libs_dir || @@defaults[:java_lib]
      end
    end

    def java_classes
      self[:java_classes] || begin
        if classes_dir = self[:classes_dir] # @deprecated
          Helpers.deprecate "please use :java_classes instead of :classes_dir"
        end
        classes_dir || File.join(java_lib, 'classes')
      end
    end

    def java_lib_dir
      @java_lib_dir ||= self[:java_lib_dir] || expand_path(java_lib)
    end

    def java_classes_dir
      @java_classes_dir ||= self[:java_classes_dir] || expand_path(java_classes)
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
      unless threadsafe?
        add_context_param 'jruby.initial.runtimes', jruby_initial_runtimes
        add_context_param 'jruby.runtime.acquire.timeout', jruby_runtime_acquire_timeout
      end
      if compat_version = jruby_compat_version
        add_context_param 'jruby.compat.version', compat_version
      end
      add_context_param 'public.root', public_root
      add_context_param 'jruby.rack.layout_class', layout_class
      # JRuby::Rack::ErrorApp got a bit smarter so use it, TODO maybe override ?
      add_context_param 'jruby.rack.error', false # do not start error app on errors
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

    # TODO: internal API - should be configurable/adjustable with context.yml !
    def context_manager; Java::RbTrinidadContext::DefaultManager.new end

    def logging
      @logging ||= begin
        defaults = {
          :level => log, # backwards compatibility
          :use_parent_handlers => ( environment == 'development' ),
          :file => {
            :dir => log_dir,
            :prefix => environment,
            :suffix => '.log',
            :rotate => true
          }
        }
        Configuration.merge_options(defaults, self[:logging])
      end
    end

    def deployment_descriptor
      return nil if @deployment_descriptor == false
      @deployment_descriptor ||= expand_path(web_xml) || false
    end

    # @deprecated use {#deployment_descriptor}
    def default_deployment_descriptor
      return nil if @default_deployment_descriptor == false
      @default_deployment_descriptor ||= expand_path(default_web_xml) || false
    end

    def public_root
      @public_root ||= ( public_config[:root] || @@defaults[:public] )
    end
    alias_method :public, :public_root

    # we do support nested :public configuration e.g. :
    # public:
    #   root: /assets
    #   cache: true
    #   cache_ttl: 60000
    def public_config
      @public_config ||= begin; public = self[:public]
        public.is_a?(String) ? { :root => public } : ( public || {} )
      end
    end

    def aliases # :public => { :aliases => ... }
      return nil unless aliases = ( self[:aliases] || public_config[:aliases] )
      return aliases if aliases.is_a?(String)
      # "/aliasPath1=docBase1,/aliasPath2=docBase2"
      @aliases ||= aliases.map do |path, base|
        path = path.to_s
        if (root = '/') != path[0, 1]
          path = (root << path)
        end
        "#{path}=#{File.expand_path(base, root_dir)}"
      end.join(',')
    end

    def caching_allowed? # :public => { :cached => ... }
      # ((BaseDirContext) resources).setCached(isCachingAllowed())
      return @caching_allowed unless @caching_allowed.nil?
      @caching_allowed = self[:caching_allowed]
      if @caching_allowed.nil?
        @caching_allowed = public_config[:cached]
        @caching_allowed = environment != 'development' if @caching_allowed.nil?
      end
      @caching_allowed = !! @caching_allowed
    end

    # The cache max size in kB
    def cache_max_size # :public => { :cache_max_size => ... }
      # ((BaseDirContext) resources).setCacheMaxSize
      self[:cache_max_size] || public_config[:cache_max_size]
    end

    # The max size for a cached object in kB
    def cache_object_max_size # :public => { :cache_object_max_size => ... }
      # ((BaseDirContext) resources).setCacheObjectMaxSize
      self[:cache_object_max_size] || public_config[:cache_object_max_size]
    end

    # Cache entry time-to-live in millis
    def cache_ttl # :public => { :cache_ttl => ... }
      # ((BaseDirContext) resources).setCacheTTL
      self[:cache_ttl] || public_config[:cache_ttl]
    end

    def define_lifecycle
      Lifecycle::WebApp::Default.new(self)
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
        if ! web_xml_servlet?(DEFAULT_SERVLET_CLASS, DEFAULT_SERVLET_NAME)
          default_servlet = self[:default_servlet]
          if default_servlet.is_a?(javax.servlet.Servlet)
            { :instance => default_servlet }
          elsif default_servlet == false
            false # forced by user to remove
          elsif default_servlet == true
            true # forced by user to leave as is
          else
            default_servlet = {} if default_servlet.nil?
            unless default_servlet.key?(:class)
              # we use a custom class by default to server /public assets :
              default_servlet[:class] = 'rb.trinidad.servlets.DefaultServlet'
            end
            default_servlet
          end
        else
          false # configured in web.xml thus remove the (default) "default"
        end
      end
    end

    JSP_SERVLET_CLASS = nil # by default we resolve by it's name
    JSP_SERVLET_NAME = 'jsp'

    # Returns a servlet config for the JspServlet.
    # This servlet is setup by default for every Tomcat context and is named
    # 'jsp' with '*.jsp' and '*.jspx' mappings.
    # Return values should be interpreted as follows :
    #  true - do nothing leave the servlet as set-up (by default)
    #  false - remove the set-up servlet (by default we do not need jsp support)
    def jsp_servlet
      return @jsp_servlet unless @jsp_servlet.nil?
      @jsp_servlet ||= begin
        if ! web_xml_servlet?(JSP_SERVLET_CLASS, JSP_SERVLET_NAME)
          jsp_servlet = self[:jsp_servlet]
          if jsp_servlet.is_a?(javax.servlet.Servlet)
            { :instance => jsp_servlet }
          else
            jsp_servlet || false # remove jsp support unless specified
          end
        else
          false # configured in web.xml thus remove the default "jsp"
        end
      end
    end

    RACK_SERVLET_CLASS = 'org.jruby.rack.RackServlet'
    RACK_SERVLET_NAME = 'rack' # in-case of a "custom" rack servlet class
    RACK_FILTER_CLASS = 'org.jruby.rack.RackFilter'
    RACK_FILTER_NAME = 'rack'

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
              ! web_xml_filter?(RACK_FILTER_CLASS, RACK_FILTER_NAME)
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
              logger.info "Ignoring :rack_servlet configuration for " <<
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
      jruby_min_runtimes == 1 && jruby_max_runtimes == 1 # handles [:threadsafe]
    end

    protected

    def context_listener
      raise NotImplementedError.new "context_listener expected to be redefined"
    end

    def layout_class
      'JRuby::Rack::FileSystemLayout' # handles Rails as well as Rack
    end

    def complete_config!
      config[:root_dir] ||= self.class.root_dir(config, default_config)
      config[:root_dir] = File.expand_path(config[:root_dir])
      config[:context_path] = self.class.context_path(config, default_config)

      return if key?(:jruby_max_runtimes) || key?(:jruby_min_runtimes)

      if ( ! key?(:threadsafe) && ! detect_threadsafe? ) || self[:threadsafe] == false
        max_runtimes = config[:jruby_max_runtimes] = guess_max_runtimes
        if environment == 'development' || environment == 'test'
          config[:jruby_min_runtimes] = 1
        else
          config[:jruby_min_runtimes] = max_runtimes
        end
      else
        config[:jruby_min_runtimes] = config[:jruby_max_runtimes] = 1
      end
    end

    def detect_threadsafe?(environment = self.environment); true end

    def guess_max_runtimes; 5 end

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
    def web_xml_filter?(filter_class, filter_name = nil)
      return nil unless web_xml_doc
      if filter_class
        filter_xpath = "/web-app/filter[filter-class = '#{filter_class}']"
        return true if web_xml_doc.root.elements[filter_xpath] # else try name
      end
      if filter_name
        filter_xpath = "/web-app/filter[filter-name = '#{filter_name}']"
        return !! web_xml_doc.root.elements[filter_xpath]
      end

      return false if filter_class || filter_name
      raise ArgumentError, "nor filter_class nor filter_name given"
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

    def web_xml_environment; nil; end

    private

    def web_xml_doc
      return @web_xml_doc || nil unless @web_xml_doc.nil?
      descriptor = deployment_descriptor
      if descriptor && File.exist?(descriptor)
        begin
          require 'rexml/document'
          @web_xml_doc = REXML::Document.new(File.read(descriptor))
        rescue REXML::ParseException => e
          logger.warn "Invalid deployment descriptor:[#{descriptor}]\n #{e.message}"
          @web_xml_doc = false
        end
        @web_xml_doc || nil
      end
    end

    def expand_path(path)
      if path
        path_file = java.io.File.new(path)
        if path_file.absolute?
          path_file.absolute_path
        else
          File.expand_path(path, root_dir)
        end
      end
    end

    def fetch_config_value(name, default = nil)
      value = config[name]
      value.nil? ? fetch_default_config_value(name, default) : value
    end

    def fetch_default_config_value(name, default = nil)
      value = default_config[name]
      if value.nil?
        # JRuby-Rack names: jruby_min_runtimes -> jruby.min.runtimes :
        value = ENV_JAVA[ name.to_s.gsub('_', '.') ]
        value ||= default
      end
      value
    end

    def logger
      @logger ||= Logging::LogFactory.getLog('')
    end

    class << self

      def rackup?(config, default_config = nil)
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

      def rails?(config, default_config = nil)
        root_dir = root_dir(config, default_config)
        # standard Rails 3.x/4.x `class Application < Rails::Application`
        if File.exists?(application = File.join(root_dir, 'config/application.rb'))
          return true if file_line_match?(application, /^[^#]*Rails::Application/)
        end
        if File.exists?(environment = File.join(root_dir, 'config/environment.rb'))
          return true if file_line_match?(environment) do |line|
            # customized Rails >= 3.x, expects a `Rails::Application` subclass
            # or a plain-old Rails 2.3 with `RAILS_GEM_VERSION = '2.3.14'`
            line =~ /^[^#]*Rails::Application/ || line =~ /^[^#]*RAILS_GEM_VERSION/
          end
        end
        false
      end

      def war?(config, default_config = nil)
        root_dir = root_dir(config, default_config)
        return true if root_dir && root_dir.to_s[-4..-1] == '.war'
        context_path = config[:context_path] # backwards-compatibility :
        context_path && context_path.to_s[-4..-1] == '.war'
      end

      def root_dir(config, default_config, default_dir = Dir.pwd)
        # for backwards compatibility accepts the :web_app_dir "alias"
        config[:root_dir] || config[:web_app_dir] ||
          ( default_config &&
            ( default_config[:root_dir] || default_config[:web_app_dir] ) ) ||
              default_dir
      end

      def context_path(config, default_config = nil)
        path = config[:context_path] ||
          ( default_config && default_config[:context_path] )
        unless path
          name = config[:context_name] ||
            ( default_config && default_config[:context_name] )
          path = name.to_s == 'default' ? '/' : "/#{name}"
        end
        path.to_s[0, 1] != '/' ? "/#{path}" : path.to_s
      end

      private

      def file_line_match?(path, pattern = nil)
        File.open(path) do |file|
          if block_given?
            file.each_line { |line| return true if yield(line) }
          else
            file.each_line { |line| return true if line =~ pattern }
          end
        end
        false
      end

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

    end

  end

  # Rack web application (looks for a "rackup" *config.ru* file).
  class RackWebApp < WebApp

    def context_params
      add_context_param 'app.root', app_root
      add_context_param 'rack.env', environment
      if rackup = self.rackup
        rackup = File.join(rackup, 'config.ru') if File.directory?(rackup)
        add_context_param 'rackup.path', rackup
      end
      super
    end

    def context_listener; 'org.jruby.rack.RackServletContextListener'; end

    def web_xml_environment; web_xml_context_param('rack.env'); end

  end
  RackupWebApp = RackWebApp

  # Rails web application specifics (supports same versions as JRuby-Rack).
  class RailsWebApp < WebApp

    def context_params
      add_context_param 'rails.root', app_root
      add_context_param 'rails.env', environment
      super
    end

    def context_listener; 'org.jruby.rack.rails.RailsServletContextListener'; end

    def web_xml_environment; web_xml_context_param('rails.env'); end

    protected

    # NOTE: maybe we can guess these based on connector maxThreads?
    # def guess_max_runtimes; 5 end

    def detect_threadsafe?(environment = self.environment)
      if environment == 'development' || environment == 'test'
        # NOTE: it's best for development/test to use the same setup as in
        # production by default, thread-safe likely won't be detected as :
        #
        #  __environments/development.rb__
        #
        #  # In the development environment your application's code is reloaded on
        #  # every request. This slows down response time but is perfect for development
        #  # since you don't have to restart the web server when you make code changes.
        #  config.cache_classes = false
        #
        #  # Do not eager load code on boot.
        #  config.eager_load = false
        #
        #  __environments/test.rb__
        #
        #  # The test environment is used exclusively to run your application's
        #  # test suite. You never need to work with it otherwise. Remember that
        #  # your test database is "scratch space" for the test suite and is wiped
        #  # and recreated between test runs. Don't rely on the data there!
        #  config.cache_classes = true
        #
        #  # Do not eager load code on boot. This avoids loading your whole application
        #  # just for the purpose of running a single test. If you are using a tool that
        #  # preloads Rails for running tests, you may have to set it to true.
        #  config.eager_load = false
        #
        return self.class.threadsafe?(root_dir, 'production')
      end
      self.class.threadsafe?(root_dir, environment)
    end

    def self.threadsafe?(app_base, environment)
      threadsafe_match?("#{app_base}/config/environments/#{environment}.rb") ||
        threadsafe_match?("#{app_base}/config/environment.rb")
    end

    def self.threadsafe_match?(file)
      File.exist?(file) && (
        file_line_match?(file, /^[^#]*threadsafe!/) || ( # Rails 4.x
          file_line_match?(file, /^[^#]*config\.eager_load\s?*=\s?*true/) &&
          file_line_match?(file, /^[^#]*config\.cache_classes\s?*=\s?*true/)
        )
      )
    end

  end

  # A web application for deploying (java) .war files.
  class WarWebApp < WebApp

    def root_dir
      @root_dir ||= ( config[:root_dir] || begin
        path = config[:context_path]
        path.to_s if path.to_s[-4..-1] == '.war'
      end || default_confit[:root_dir] )
    end

    def context_path
      @path ||= begin
        path = File.basename(super)
        context_name = Tomcat::ContextName.new(path)
        context_name.path # removes .war handles ## versioning
      end
    end

    def work_dir
      self[:work_dir]
    end

    def log_dir
      @log_dir ||= self[:log_dir] || begin
        if work_dir then work_dir
        else
          if root_dir[-4..-1] == '.war'
            parent_dir = File.dirname(root_dir)
            expanded_dir = File.join(parent_dir, context_path)
            File.exist?(expanded_dir) ? expanded_dir : parent_dir
          else
            File.join(root_dir, 'log')
          end
        end
      end
    end

    def monitor
      root_dir ? File.expand_path(root_dir) : nil # the .war file itself
    end

    def context_params
      warbler? ? super : @context_params ||= {}
    end

    def context_manager; nil end

    def layout_class
      'JRuby::Rack::WebInfLayout'
    end

    def define_lifecycle
      Lifecycle::WebApp::War.new(self)
    end

    private

    def warbler?; nil; end # TODO detect warbler created .war ?!

  end

end
