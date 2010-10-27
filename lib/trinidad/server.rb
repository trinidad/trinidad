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
        :log => 'INFO'
      }
    end

    def initialize(config = {})
      load_config(config)
      load_tomcat_server
      create_web_apps
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
      if @config[:web_apps]
        @config[:web_apps].each do |name, app_config|
          app_config[:context_path] ||= (name.to_s == 'default' ? '/' : "/#{name.to_s}")
          app_config[:web_app_dir] ||= Dir.pwd

          create_web_app(app_config)
        end
      end
      if @config[:apps_base]
        apps_path = Dir.glob(File.join(@config[:apps_base], '*')).select {|path| !(path =~ /tomcat\.8080$/) }

        apps_path.each do |path|
          if File.directory?(path)
            name = File.basename(path)
            app_config = {
              :context_path => (name == 'default' ? '/' : "/#{name.to_s}"),
              :web_app_dir => File.expand_path(path)
            }

            create_web_app(app_config)
          end
        end
      end
    end

    def create_web_app(app_config)
      app_context = @tomcat.addWebapp(app_config[:context_path], app_config[:web_app_dir])
      app_context.work_dir = app_config[:web_app_dir]
      remove_defaults(app_context)

      web_app = WebApp.create(@config, app_config)

      Trinidad::Extensions.configure_webapp_extensions(web_app.extensions, @tomcat, app_context)
      app_context.add_lifecycle_listener(WebAppLifecycleListener.new(web_app))
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
      options[:address] ||= @config[:address]
      options[:port] = @config[:port]
      options[:protocol_handler] = 'org.apache.coyote.http11.Http11NioProtocol' if options[:nio]

      connector = add_service_connector(options, options[:protocol_handler])
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
      @tomcat.start
      @tomcat.server.await
    end

    private

    def add_default_web_app!(config)
      if (!config.has_key?(:web_apps) && !config.has_key?(:apps_base))
        default_app = {
          :context_path => config[:context_path] || '/',
          :web_app_dir => config[:web_app_dir] || Dir.pwd,
          :log => config[:log]
        }
        default_app[:rackup] = config[:rackup] if (config.has_key?(:rackup))

        config[:web_apps] = { :default => default_app }
      end
    end

    def remove_defaults(app_context)
      default_servlet = app_context.find_child('default')
      app_context.remove_child(default_servlet) if default_servlet

      jsp_servlet = app_context.find_child('jsp')
      app_context.remove_child(jsp_servlet) if jsp_servlet

      app_context.remove_servlet_mapping('/')
      app_context.remove_servlet_mapping('*.jspx')
      app_context.remove_servlet_mapping('*.jsp')

      app_context.process_tlds = false
    end

  end
end
