require 'trinidad/configuration'
require 'trinidad/web_app'

module Trinidad
  class Server
    attr_reader :config

    def initialize(config = Trinidad.configuration)
      configure(config)
    end

    def configure(config = Trinidad.configuration)
      configure_logging config[:log]
      @config = config.freeze
    end
     # @deprecated replaced with {#configure}
    def load_config(config); configure(config); end

    def hosts
      @hosts ||= @config[:hosts]
    end
    attr_writer :hosts
    
    def app_base
      @app_base ||= @config[:app_base] || @config[:apps_base]
    end
    attr_writer :app_base

    def web_apps
      @web_apps ||= @config[:web_apps] || @config[:webapps]
    end
    attr_writer :web_apps
    
    def trap?
      @trap ||= @config[:trap] if ! defined?(@trap) || @trap.nil?
      @trap
    end
    attr_writer :trap

    def ssl_enabled?
      if ! defined?(@ssl_enabled) || @ssl_enabled.nil?
        @ssl_enabled ||= ( !! @config[:ssl] && ! @config[:ssl].empty? )
      end
      @ssl_enabled
    end
    attr_writer :ssl_enabled

    def ajp_enabled?
      if ! defined?(@ajp_enabled) || @ajp_enabled.nil?
        @ajp_enabled ||= ( !! @config[:ajp] && ! @config[:ajp].empty? )
      end
      @ajp_enabled
    end
    attr_writer :ajp_enabled

    def http_configured?
      if ! defined?(@http_configured) || @http_configured.nil?
        @http_configured ||= 
        ( ( !! @config[:http] && ! @config[:http].empty? ) || @config[:address] != 'localhost' )
      end
      @http_configured
    end
    attr_writer :http_configured
    
    def tomcat; @tomcat ||= initialize_tomcat; end

    def initialize_tomcat
      set_system_properties

      tomcat = Trinidad::Tomcat::Tomcat.new
      tomcat.base_dir = config[:base_dir] || Dir.pwd
      tomcat.hostname = config[:address] || 'localhost'
      tomcat.server.address = config[:address]
      tomcat.port = config[:port].to_i
      tomcat.host # initializes default host
      create_hosts(tomcat)
      tomcat.enable_naming

      add_http_connector(tomcat) if http_configured?
      add_ssl_connector(tomcat)  if ssl_enabled?
      add_ajp_connector(tomcat)  if ajp_enabled?

      Trinidad::Extensions.configure_server_extensions(config[:extensions], tomcat)
    end
    protected :initialize_tomcat
    # #deprecated renamed to {#initialize_tomcat}
    def load_tomcat_server; initialize_tomcat; end

    def setup_host_monitor(app_holders)
      for host in tomcat.engine.find_children
        if host.is_a?(Trinidad::Tomcat::Host)
          host_apps = select_host_apps(app_holders, host)
          host.add_lifecycle_listener(Trinidad::Lifecycle::Host.new(self, *host_apps))
        end
      end
    end
    protected :setup_host_monitor
    # @deprecated replaced with {#setup_host_monitor}
    def load_host_monitor(web_apps); setup_host_monitor(web_apps); end

    def add_ajp_connector(tomcat = @tomcat)
      add_service_connector(@config[:ajp], 'AJP/1.3', tomcat)
    end

    def add_http_connector(tomcat = @tomcat)
      options = config[:http] || {}
      options[:address] ||= @config[:address] if @config[:address] != 'localhost'
      options[:port] = @config[:port]
      options[:protocol_handler] = 'org.apache.coyote.http11.Http11NioProtocol' if options[:nio]

      if options[:apr]
        tomcat.server.add_lifecycle_listener(Trinidad::Tomcat::AprLifecycleListener.new)
      end

      connector = add_service_connector(options, options[:protocol_handler] || 'HTTP/1.1', tomcat)
      tomcat.connector = connector
    end
    
    def add_ssl_connector(tomcat = @tomcat)
      options = config[:ssl].merge({
        :scheme => 'https',
        :secure => true,
        :SSLEnabled => 'true'
      })

      options[:keystoreFile] ||= options.delete(:keystore)

      if ! options[:keystoreFile] && ! options[:SSLCertificateFile]
        options[:keystoreFile] = 'ssl/keystore'
        options[:keystorePass] = 'waduswadus42'
        generate_default_keystore(options)
      end

      add_service_connector(options, nil, tomcat)
    end
    
    def add_service_connector(options, protocol = nil, tomcat = @tomcat)
      opts = options.dup

      connector = Trinidad::Tomcat::Connector.new(protocol)
      connector.scheme = opts.delete(:scheme) if opts[:scheme]
      connector.secure = opts.delete(:secure) || false
      connector.port = opts.delete(:port).to_i

      connector.protocol_handler_class_name = opts.delete(:protocol_handler) if opts[:protocol_handler]

      opts.each { |key, value| connector.setProperty(key.to_s, value.to_s) }

      tomcat.service.add_connector(connector)
      connector
    end
    private :add_service_connector

    def add_web_app(web_app, host = nil, start = nil)
      host ||= begin 
        name = web_app.host_name
        name ? find_host(name, tomcat) : tomcat.host
      end
      prev_start = host.start_children
      context = begin
        host.start_children = start unless start.nil?
        # public Context addWebapp(Host host, String url, String name, String docBase)
        tomcat.addWebapp(host, web_app.context_path, web_app.context_name, web_app.root_dir)
      ensure
        host.start_children = prev_start unless start.nil?
      end
      Trinidad::Extensions.configure_webapp_extensions(web_app.extensions, tomcat, context)
      if lifecycle = web_app.define_lifecycle
        context.add_lifecycle_listener(lifecycle)
      end
      context
    end
    
    def deploy_web_apps(tomcat = self.tomcat)
      web_app_holders = create_web_apps
      setup_host_monitor(web_app_holders)
      web_app_holders
    end

    def start
      deploy_web_apps(tomcat)

      trap_signals if trap?

      tomcat.start
      tomcat.server.await
    end

    def start!
      if defined?(@tomcat) && @tomcat
        @tomcat.destroy; @tomcat = nil
      end
      start
    end

    def stop
      if defined?(@tomcat) && @tomcat
        @tomcat.stop; true
      end
    end

    def stop!
      (@tomcat.destroy; true) if stop
    end
    
    protected

    def create_web_apps
      # add default web app if needed :
      if ! web_apps && ! app_base && ! hosts
        default_app = {
          :context_path => config[:context_path],
          :root_dir => web_app_root_dir(config),
          :log => config[:log]
        }
        default_app[:rackup] = config[:rackup] if config[:rackup]

        self.web_apps = { :default => default_app }
      end

      apps = []

      # configured :web_apps
      web_apps.each do |name, app_config|
        app_config[:context_name] ||= name
        apps << create_web_app(app_config)
      end if web_apps

      # configured :app_base or :hosts
      tomcat.engine.find_children.each do |host|
        host_base = host.app_base

        apps_path = Dir.glob(File.join(host_base, '*')).
          select { |path| ! ( path =~ /tomcat\.\d+$/ ) } # TODO
        apps_path.reject! { |path| apps_path.include?(path + '.war') } # TODO

        apps_path.each do |path|
          if File.directory?(path) || path =~ /\.war$/
            apps << create_web_app({
              :context_name => File.basename(path),
              :root_dir => File.expand_path(path),
              :host_name => host.name
            })
          end
        end
      end if app_base || hosts

      apps
    end

    def create_web_app(app_config)
      web_app = WebApp.create(app_config, config)
      WebApp::Holder.new(web_app, add_web_app(web_app))
    end

    def create_hosts(tomcat = @tomcat)
      hosts.each do |app_base, host_config|
        if host = find_host(app_base, host_config, tomcat)
          setup_host(app_base, host_config, host)
        else
          create_host(app_base, host_config, tomcat)
        end
      end if hosts

      default_host = tomcat.host
      default_app_base = ( default_host.app_base == DEFAULT_HOST_APP_BASE )
      if self.app_base || 
        ( default_app_base && ! File.exists?(DEFAULT_HOST_APP_BASE) )
        tomcat.host.app_base = self.app_base || Dir.pwd
      end

      web_app_hosts = []
      # create hosts as they are specified for each app in :web_apps :
      # e.g. :app1 => { :root_dir => 'app1', :hosts => 'virtual.host' }
      web_apps.each do |_, app_config|
        if host_names = app_config[:hosts] || app_config[:host]
          app_root = File.expand_path web_app_root_dir(app_config)
          if host = find_host(host_names, tomcat)
            set_host_app_base(app_root, host, default_host, web_app_hosts)
          else
            # for created hosts -> web-app per host by default
            # thus new host's app_base will point to root_dir :
            host = create_host(app_root, host_names, tomcat)
            web_app_hosts << host
          end
          app_config[:host_name] = host.name
        end
      end if web_apps
    end

    def create_host(app_base, host_config, tomcat = @tomcat)
      host = Trinidad::Tomcat::StandardHost.new
      host.app_base = nil # reset default app_base
      host.auto_deploy = false # disable by default
      setup_host(app_base, host_config, host)
      tomcat.engine.add_child host if tomcat
      host
    end
    
    def setup_host(app_base, host_config, host)
      if host_config.is_a?(Array)
        name = host_config.shift
        host_config = { :name => name, :aliases => host_config }
      elsif host_config.is_a?(String) || host_config.is_a?(Symbol)
        host_config = { :name => host_config }
      else
        host_config[:name] ||= app_base
      end
      host_config[:app_base] ||= app_base if app_base.is_a?(String)

      host_config.each do |name, value|
        case (name = name.to_sym)
        when :app_base
          host.app_base = value if default_host_base?(host)
        when :aliases
          aliases = host.find_aliases || []
          value.each do |name|
            next if (name = name.to_s) == host.name
            host.add_alias(name) unless aliases.include?(name)
          end if host_config[:aliases]
        else
          value = value.to_s if value.is_a?(Symbol)
          host.send("#{name}=", value) # e.g. host.name = value
        end
      end
    end

    def set_system_properties(system = Java::JavaLang::System)
      system.set_property("org.apache.catalina.startup.EXIT_ON_INIT_FAILURE", 'true')
    end
    # @deprecated renamed to {#set_system_properties}
    def load_default_system_properties; set_system_properties; end
    
    def configure_logging(log_level)
      Trinidad::Logging.configure(log_level)
    end

    private
    
    DEFAULT_HOST_APP_BASE = 'webapps' # :nodoc:

    def default_host_base?(host)
      host.app_base.nil? || ( host.app_base == DEFAULT_HOST_APP_BASE && host.name == 'localhost' )
    end

    def set_host_app_base(app_root, host, default_host, web_app_hosts)
      if host.app_base # we'll try setting a common parent :
        require 'pathname'; app_path = Pathname.new(app_root)
        app_real_path = begin; app_path.realpath.to_s; rescue
          Helpers.warn "WARN: web app root #{app_path.to_s.inspect} does not exists" 
          return
        end
        base_path = Pathname.new host.app_base; base_parent = false
        2.times do
          begin
            break if base_parent = app_real_path.index(base_path.realpath.to_s) == 0
          rescue => e
            Helpers.warn "WARN: app_base for host #{host.name.inspect} seems to" <<
            " not exists, try configuring an absolute path or create it\n (#{e.message})"
            return
          end
          base_path = base_path.parent
        end
        if base_parent
          return if base_path.to_s == host.app_base
          host.app_base = base_path.realpath.to_s
          unless web_app_hosts.include?(host)
            Helpers.warn "NOTE: changed (configured) app_base for host #{host.name.inspect}" <<
            " to #{host.app_base.inspect} to include web_app root: #{app_path.to_s.inspect}"
          end
        else
          Helpers.warn "WARN: app_base for host #{host.name.inspect} #{host.app_base.inspect}" <<
          " is not a parent directory for web_app root: #{app_path.to_s.inspect}"
        end
      else
        host.app_base = app_path.parent.realpath.to_s
      end
    end

    def select_host_apps(app_holders, host)
      app_holders.select do |app_holder|
        host_name = app_holder.web_app.host_name
        host_name.nil? || host_name == host.name
      end
    end

    def find_host(name, host_config, tomcat = nil)
      if tomcat.nil? # assume 2 args (host_config, tomcat)
        tomcat = host_config; host_config = name
      end

      if host_config.is_a?(Array)
        names = host_config
      elsif host_config.is_a?(String) || host_config.is_a?(Symbol)
        names = [ host_config ]
      elsif host_config # :localhost => { :aliases => 'local,127.0.0.1' ... }
        names = [ host_config[:name] ||= name ]
        aliases = host_config[:aliases]
        if aliases && ! aliases.is_a?(Array)
          aliases = aliases.split(',').each(&:strip!)
          host_config[:aliases] = aliases
        end
      else # only name passed :
        return tomcat.engine.find_child(name.to_s)
      end

      hosts = tomcat.engine.find_children
      for name in names # host_names
        host = hosts.find do |host|
          host.name == name || (host.aliases || []).include?(name)
        end
        return host if host
      end
      nil
    end

    def web_app_root_dir(config, default = Dir.pwd)
      config[:root_dir] || config[:web_app_dir] || default
    end
    
    def generate_default_keystore(config)
      keystore_file = java.io.File.new(config[:keystoreFile])

      if ! keystore_file.parent_file.exists && ! keystore_file.parent_file.mkdir
          raise "Unable to create keystore folder: #{keystore_file.parent_file.canonical_path}"
      end

      key_tool_args = ["-genkey",
        "-alias", "localhost",
        "-dname", "CN=localhost, OU=Trinidad, O=Trinidad, C=ES",
        "-keyalg", "RSA",
        "-validity", "365",
        "-storepass", "key",
        "-keystore", config[:keystoreFile],
        "-storepass", config[:keystorePass],
        "-keypass", config[:keystorePass]]

      key_tool = Java::SunSecurityTools::KeyTool
      key_tool.main key_tool_args.to_java(:string)
    end
    
    def trap_signals
      trap('INT') { stop! }
      trap('TERM') { stop! }
    end
    
  end
end
