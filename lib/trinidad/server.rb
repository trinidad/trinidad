require 'trinidad/configuration'
require 'trinidad/web_app'

module Trinidad
  class Server
    attr_reader :config

    def initialize(config = Trinidad.configuration)
      configure(config)
    end

    def configure(config = Trinidad.configuration)
      configure_logging config[:logging] || config[:log]
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
      @trap = !! @config[:trap] if ! defined?(@trap) || @trap.nil?
      @trap
    end
    attr_writer :trap

    def ssl_enabled?
      if ! defined?(@ssl_enabled) || @ssl_enabled.nil?
        @ssl_enabled = ( !! @config[:ssl] && ! @config[:ssl].empty? )
      end
      @ssl_enabled
    end
    attr_writer :ssl_enabled

    def ajp_enabled?
      if ! defined?(@ajp_enabled) || @ajp_enabled.nil?
        ajp = @config[:ajp]
        @ajp_enabled = ( !! ajp && ( ! ajp.respond_to?(:empty?) || ! ajp.empty? ) )
      end
      @ajp_enabled
    end
    attr_writer :ajp_enabled

    def http_configured?
      if ! defined?(@http_configured) || @http_configured.nil?
        http = @config[:http]
        @http_configured = ( !! http && ( ! http.respond_to?(:empty?) || ! http.empty? ) )
      end
      @http_configured
    end
    attr_writer :http_configured

    def tomcat; @tomcat ||= initialize_tomcat; end

    LOCALHOST = 'localhost'.freeze # :nodoc:

    def initialize_tomcat
      set_system_properties

      tomcat = Trinidad::Tomcat::Tomcat.new
      tomcat.base_dir = config[:base_dir] || Dir.pwd
      tomcat.hostname = config[:address] || LOCALHOST
      tomcat.server.address = config[:address]
      tomcat.port = config[:port].to_i
      default_host(tomcat)
      create_hosts(tomcat)
      tomcat.enable_naming

      http_connector = http_configured? ||
        ( ! ajp_enabled? && config[:address] && config[:address] != LOCALHOST )

      if http_connector
        tomcat.connector = add_http_connector(tomcat)
      end
      if ajp_enabled?
        connector = add_ajp_connector(tomcat)
        tomcat.connector = connector unless http_connector
      end
      add_ssl_connector(tomcat) if ssl_enabled?

      Trinidad::Extensions.configure_server_extensions(config[:extensions], tomcat)
    end
    protected :initialize_tomcat
    # #deprecated renamed to {#initialize_tomcat}
    def load_tomcat_server; initialize_tomcat; end

    def add_host_monitor(app_holders)
      for host in tomcat.engine.find_children
        host_apps = select_host_apps(app_holders, host)
        host.add_lifecycle_listener(Trinidad::Lifecycle::Host.new(self, *host_apps))
      end
    end
    protected :add_host_monitor
    # @deprecated replaced with {#setup_host_monitor}
    def load_host_monitor(web_apps); add_host_monitor(web_apps); end

    def add_ajp_connector(tomcat = @tomcat)
      options = config[:ajp]
      options = {
        :address => @config[:address], :port => @config[:port]
      }.merge!( options.respond_to?(:[]) ? options : {} )

      add_service_connector(options, options[:protocol_handler] || 'AJP/1.3', tomcat)
    end

    def add_http_connector(tomcat = @tomcat)
      options = config[:http]
      options = {
        :address => @config[:address], :port => @config[:port]
      }.merge!( options.respond_to?(:[]) ? options : {} )

      if options.delete(:nio)
        options[:protocol_handler] ||= 'org.apache.coyote.http11.Http11NioProtocol'
      end

      if options.delete(:apr)
        tomcat.server.add_lifecycle_listener(Trinidad::Tomcat::AprLifecycleListener.new)
      end

      add_service_connector(options, options[:protocol_handler] || 'HTTP/1.1', tomcat)
    end

    def add_ssl_connector(tomcat = @tomcat)
      options = config[:ssl]
      options = {
        :scheme => 'https', :secure => true, :SSLEnabled => 'true'
      }.merge!( options.respond_to?(:[]) ? options : {} )

      options[:keystoreFile] ||= options.delete(:keystore)

      if ! options[:keystoreFile] && ! options[:SSLCertificateFile]
        options[:keystoreFile] ||= 'ssl/keystore'
        options[:keystorePass] ||= 'waduswadus42'
        generate_default_keystore(options)
      end

      add_service_connector(options, nil, tomcat)
    end

    # NOTE: make sure to pass an options Hash that might be changed !
    def add_service_connector(options, protocol = nil, tomcat = @tomcat)
      connector = Trinidad::Tomcat::Connector.new(protocol)
      connector.scheme = options.delete(:scheme) if options[:scheme]
      connector.secure = options.delete(:secure) || false
      connector.port = options.delete(:port).to_i if options[:port]

      if handler = options.delete(:protocol_handler)
        connector.protocol_handler_class_name = handler
      end

      options.each { |key, value| connector.setProperty(key.to_s, value.to_s) }

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
      rescue java.lang.IllegalArgumentException => e
        if e.message =~ /addChild\:/
          context_name = web_app.context_name
          logger.error "could not add application #{context_name.inspect} from #{web_app.root_dir}\n" <<
                       " (same context name is used for #{host.find_child(context_name).doc_base})"
          raise "there's already an application named #{context_name.inspect} for host #{host.name.inspect}"
        end
        raise e
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
      web_apps = create_web_apps
      add_host_monitor web_apps
      web_apps
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
        default_app = { :context_path => config[:context_path] }
        root_dir = web_app_root_dir(config) || Dir.pwd
        default_app[:root_dir] = root_dir if root_dir != false
        default_app[:rackup] = config[:rackup] if config[:rackup]

        self.web_apps = { :default => default_app }
      end

      apps = []

      # configured :web_apps
      web_apps.each do |name, app_config|
        app_config[:context_name] ||= name
        apps << ( app_holder = create_web_app(app_config) ); app = app_holder.web_app
        logger.info "Deploying from #{app.root_dir} as #{app.context_path}"
      end if web_apps

      # configured :app_base or :hosts - scan for applications in host's app_base directory :
      tomcat.engine.find_children.each do |host|
        apps_path = java.io.File.new(host.app_base).list.to_a
        if host.deploy_ignore # respect deploy ignore pattern (even if not deploying on startup)
          deploy_ignore_pattern = Regexp.new(host.deploy_ignore)
          apps_path.reject! { |path| path =~ deploy_ignore_pattern }
        end
        # we do a bit of "default" filtering for hosts of our own :
        work_dir = host.work_dir
        apps_path.reject! do |path|
          if path[0, 1] == '.' then true # ignore "hidden" files
          elsif work_dir && work_dir == path then true
          elsif ! work_dir && path =~ /tomcat\.\d+$/ then true # [host_base]/tomcat.8080
          elsif path[-4..-1] == '.war' && apps_path.include?(path[0...-4]) # only keep expanded .war
            logger.info "Expanded .war at #{path} - only deploying directory (.war ignored)"
            true
          end
        end

        apps_path.each do |path| # host web apps (from dir or .war files)
          app_root = File.expand_path(path, host.app_base)
          if File.directory?(app_root) || ( app_root[-4..-1] == '.war' )
            app_base_name = File.basename(app_root)
            deployed = apps.find do |app_holder|; web_app = app_holder.web_app
              web_app.root_dir == app_root ||
                web_app.context_path == Trinidad::Tomcat::ContextName.new(app_base_name).path
            end
            if deployed
              logger.debug "Skipping auto-deploy from #{app_root} (already deployed)"
            else
              apps << ( app_holder = create_web_app({
                :context_name => path, :root_dir => app_root, :host_name => host.name
              }) ); app = app_holder.web_app
              logger.info "Auto-Deploying from #{app.root_dir} as #{app.context_path}"
            end
          end
        end
      end if app_base || hosts

      apps
    end

    def create_web_app(app_config)
      host_name = app_config[:host_name] || 'localhost'
      host = tomcat.engine.find_child(host_name)
      app_config[:root_dir] = web_app_root_dir(app_config, host)

      web_app = WebApp.create(app_config, config)
      WebApp::Holder.new(web_app, add_web_app(web_app))
    end

    def create_hosts(tomcat = @tomcat)
      hosts.each do |app_base, host_config|
        next if app_base == :default # @see #default_host
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
      # e.g. :app1 => { :root_dir => 'app1', :host => 'virtual.host' }
      web_apps.each do |_, app_config|
        if host_names = app_config[:hosts] || app_config[:host]
          if host = find_host(host_names, tomcat)
            app_root = web_app_root_dir(app_config, host)
            set_host_app_base(app_root, host, default_host, web_app_hosts)
          else
            app_root = web_app_root_dir(app_config)
            raise "no root for app #{app_config.inspect}" unless app_root
            app_root = File.expand_path(app_root)
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
      host.deployXML = false # disabled by default
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
          value.each do |aliaz|
            next if (aliaz = aliaz.to_s) == host.name
            host.add_alias(aliaz) unless aliases.include?(aliaz)
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

    def configure_logging(logging)
      Trinidad::Logging.configure(logging)
    end

    def logger; @logger ||= self.class.logger; end

    def self.logger
      Logging::LogFactory.getLog('org.apache.catalina.startup.Tomcat')
    end

    private

    def default_host(tomcat = @tomcat)
      host = tomcat.host # make sure we initialize default host
      host.deployXML = false
      host_config = @config[:host] || ( @config[:hosts] && @config[:hosts][:default] )
      if host_config.is_a?(String)
        host.name = host_config
      elsif host_config
        host_config.each { |name, value| host.send("#{name}=", value) }
      end
      host
    end

    DEFAULT_HOST_APP_BASE = 'webapps' # :nodoc:

    def default_host_base?(host)
      host.app_base.nil? || ( host.app_base == DEFAULT_HOST_APP_BASE && host.name == 'localhost' )
    end

    def set_host_app_base(app_root, host, default_host, web_app_hosts)
      if host.app_base # we'll try setting a common parent :
        require 'pathname'; app_path = Pathname.new(app_root)
        base_path = Pathname.new(host.app_base)
        unless app_path.exist?
          app_path = app_path.relative_path_from(base_path) rescue app_path
        end
        app_real_path = begin; app_path.realpath.to_s; rescue
          logger.warn "Application root #{app_root} does not exist !"
          return
        end
        base_parent = false
        2.times do
          begin
            if app_real_path.index(base_path.realpath.to_s) == 0
              base_parent = true; break
            end
          rescue => e
            logger.warn "Host #{host.name.inspect} app_base does not exist," <<
            " try configuring an absolute path or create it\n (#{e.message})"
            return
          end
          base_path = base_path.parent
        end
        if base_parent
          return if base_path.to_s == host.app_base
          host.app_base = base_path.realpath.to_s
          unless web_app_hosts.include?(host)
            logger.info "Changing (configured) app_base for host #{host.name.inspect}" <<
                        " (#{host.app_base}) to include application root: #{app_path}"
          end
        else
          logger.warn "Host #{host.name.inspect} app_base #{host.app_base.inspect}" <<
                      " is not a parent directory for application root: #{app_path}"
        end
      else
        host.app_base = app_path.parent.realpath.to_s
      end
    end

    def select_host_apps(app_holders, host)
      app_holders.select do |app_holder|
        host_name = app_holder.web_app.host_name
        [host_name, 'localhost', '0.0.0.0'].include?(host.name)
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

    def web_app_root_dir(config, host = nil)
      path = config[:root_dir] || config[:web_app_dir] || begin
        path = config[:context_path]
        ( path && path[0, 1] == '/' ) ? path[1..-1] : path
      end || ( config[:context_name] ? config[:context_name].to_s : nil )

      return nil if path.nil?
      return File.expand_path(path) if File.exist?(path)

      if host
        base = host.app_base
        ( path && base ) ? File.join(base, path) : path
      else
        path
      end
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
