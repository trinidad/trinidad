module Trinidad

  class Server
    attr_reader :tomcat, :config

    def default_options
      {
        :environment => 'development',
        :context_path => '/',
        :libs_dir => 'lib',
        :classes_dir => 'classes',
        :default_web_xml => 'config/web.xml',
        :port => 3000,
        :jruby_min_runtimes => 1,
        :jruby_max_runtimes => 5,
        :address => 'localhost',
        :log => 'INFO',
        :trap => true
      }
    end

    def initialize(config = {})
      load_config(config)
      load_tomcat_server
      apps = create_web_apps
      load_host_monitor(apps)
    end

    def load_config(config)
      @config = default_options.deep_merge(config).symbolize!
      add_default_web_app!(@config)
    end

    def load_tomcat_server
      @tomcat = Trinidad::Tomcat::Tomcat.new
      @tomcat.base_dir = Dir.pwd
      @tomcat.hostname = @config[:address]
      @tomcat.server.address = @config[:address]
      @tomcat.port = @config[:port].to_i
      @tomcat.host.app_base = @config[:apps_base] || Dir.pwd
      @tomcat.enable_naming

      add_http_connector if http_configured?
      add_ssl_connector if ssl_enabled?
      add_ajp_connector if ajp_enabled?

      @tomcat = Trinidad::Extensions.configure_server_extensions(@config[:extensions], @tomcat)
    end

    def create_web_apps
      apps = []
      apps << create_from_web_apps
      apps << create_from_apps_base

      apps.flatten.compact
    end

    def load_host_monitor(apps)
      @tomcat.host.add_lifecycle_listener(Trinidad::Lifecycle::Host.new(@tomcat, *apps))
    end

    def create_from_web_apps
      if @config[:web_apps]
        @config[:web_apps].map do |name, app_config|
          app_config[:context_path] ||= (name.to_s == 'default' ? '' : "/#{name.to_s}")
          app_config[:web_app_dir] ||= Dir.pwd

          create_web_app(app_config)
        end
      end
    end

    def create_from_apps_base
      if @config[:apps_base]
        apps_path = Dir.glob(File.join(@config[:apps_base], '*')).
          select {|path| !(path =~ /tomcat\.\d+$/) }

        apps_path.reject! {|path| apps_path.include?(path + '.war') }

        apps_path.map do |path|
          if (File.directory?(path) || path =~ /\.war$/)
            name = File.basename(path)
            app_config = {
              :context_path => (name == 'default' ? '' : "/#{name.to_s}"),
              :web_app_dir => File.expand_path(path)
            }

            create_web_app(app_config)
          end
        end
      end
    end

    def create_web_app(app_config)
      web_app = WebApp.create(@config, app_config)

      app_context = @tomcat.addWebapp(web_app.context_path, web_app.web_app_dir)

      Trinidad::Extensions.configure_webapp_extensions(web_app.extensions, @tomcat, app_context)

      app_context.add_lifecycle_listener(web_app.define_lifecycle)

      {:context => app_context, :app => web_app, :monitor => web_app.monitor}
    end

    def add_service_connector(options, protocol = nil)
      connector = Trinidad::Tomcat::Connector.new(protocol)
      opts = options.dup

      connector.scheme = opts.delete(:scheme) if opts[:scheme]
      connector.secure = opts.delete(:secure) || false
      connector.port = opts.delete(:port).to_i

      connector.protocol_handler_class_name = opts.delete(:protocol_handler) if opts[:protocol_handler]

      opts.each do |key, value|
        connector.setProperty(key.to_s, value.to_s)
      end

      @tomcat.service.add_connector(connector)
      connector
    end

    def add_ajp_connector
      add_service_connector(@config[:ajp], 'AJP/1.3')
    end

    def add_ssl_connector
      options = @config[:ssl].merge({
        :scheme => 'https',
        :secure => true,
        :SSLEnabled => 'true'
      })

      options[:keystoreFile] ||= options.delete(:keystore)

      if !options[:keystoreFile] && !options[:SSLCertificateFile]
        options[:keystoreFile] = 'ssl/keystore'
        options[:keystorePass] = 'waduswadus'
        create_default_keystore(options)
      end

      add_service_connector(options)
    end

    def add_http_connector
      options = @config[:http] || {}
      options[:address] ||= @config[:address] if @config[:address] != 'localhost'
      options[:port] = @config[:port]
      options[:protocol_handler] = 'org.apache.coyote.http11.Http11NioProtocol' if options[:nio]

      if options[:apr]
        @tomcat.server.add_lifecycle_listener(Trinidad::Tomcat::AprLifecycleListener.new)
      end

      connector = add_service_connector(options, options[:protocol_handler] || 'HTTP/1.1')
      @tomcat.connector = connector
    end

    def ssl_enabled?
      @config.has_key?(:ssl)
    end

    def ajp_enabled?
      @config.has_key?(:ajp)
    end

    def http_configured?
      @config.has_key?(:http) || @config[:address] != 'localhost'
    end

    def create_default_keystore(config)
      keystore_file = java.io.File.new(config[:keystoreFile])

      if (!keystore_file.parent_file.exists &&
              !keystore_file.parent_file.mkdir)
          raise "Unable to create keystore folder: " + keystore_file.parent_file.canonical_path
      end

      keytool_args = ["-genkey",
        "-alias", "localhost",
        "-dname", "CN=localhost, OU=Trinidad, O=Trinidad, C=ES",
        "-keyalg", "RSA",
        "-validity", "365",
        "-storepass", "key",
        "-keystore", config[:keystoreFile],
        "-storepass", config[:keystorePass],
        "-keypass", config[:keystorePass]]

      Trinidad::Tomcat::KeyTool.main(keytool_args.to_java(:string))
    end

    def start
      trap_signals if @config[:trap]

      @tomcat.start
      @tomcat.server.await
    end

    def stop
      @tomcat.stop
      @tomcat.destroy
    end

    private

    def add_default_web_app!(config)
      if (!config.has_key?(:web_apps) && !config.has_key?(:apps_base))
        default_app = {
          :context_path => config[:context_path],
          :web_app_dir => config[:web_app_dir] || Dir.pwd,
          :log => config[:log]
        }
        default_app[:rackup] = config[:rackup] if (config.has_key?(:rackup))

        config[:web_apps] = { :default => default_app }
      end
    end

    def trap_signals
      trap('INT') { stop }
      trap('TERM') { stop }
    end
  end
end
