module Trinidad
  class Server

    attr_reader :tomcat

    def default_options
      {
        :environment => 'development',
        :context_path => '/',
        :libs_dir => 'lib',
        :classes_dir => 'classes',
        :default_web_xml => 'config/web.xml',
        :port => 3000,
        :jruby_min_runtimes => 1,
        :jruby_max_runtimes => 5
      }
    end

    def initialize(config = {})
      load_config(config)
      load_tomcat_server
      create_web_apps
    end

    def load_config(config)
      @config = default_options.deep_merge(config)
      add_default_web_app!(@config)
    end

    def load_tomcat_server
      @tomcat = Trinidad::Tomcat::Tomcat.new
      @tomcat.setPort(@config[:port].to_i)
      @tomcat.setBaseDir(Dir.pwd)

      add_ssl_connector if ssl_enabled?
      add_ajp_connector if ajp_enabled?
    end

    def create_web_apps
      @config[:web_apps].each do |name, app|
        app[:context_path] ||= (name.to_s == 'default' ? '/' : "/#{name.to_s}")
        app[:web_app_dir] ||= Dir.pwd

        tomcat_app = @tomcat.addWebapp(app[:context_path].to_s, app[:web_app_dir])

        web_app = WebApp.create(tomcat_app, @config, app)

        web_app.load_default_web_xml
        web_app.add_rack_filter
        web_app.add_context_loader
        web_app.add_init_params
        web_app.add_web_dir_resources

        web_app.add_rack_context_listener
      end
    end

    def add_service_connector(options, protocol = nil)
      connector = Trinidad::Tomcat::Connector.new(protocol)

      opts = options.dup

      connector.scheme = opts.delete(:scheme) if opts[:scheme]
      connector.secure = opts.delete(:secure) || false
      connector.port = opts.delete(:port).to_i

      options.each do |key, value|
        connector.setProperty(key.to_s, value.to_s)
      end

      @tomcat.getService().addConnector(connector)
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
      options[:keystore] ||= 'ssl/keystore'
      options[:keystorePass] ||= 'waduswadus'

      add_service_connector(options)
      create_default_keystore(options) unless File.exist?(options[:keystore])
    end

    def ssl_enabled?
      @config.has_key?(:ssl)
    end

    def ajp_enabled?
      @config.has_key?(:ajp)
    end

    def create_default_keystore(config)
      keystore_file = java.io.File.new(config[:ssl][:keystore])

      if (!keystore_file.parent_file.exists() &&
              !keystore_file.parent_file.mkdir())
          raise "Unable to create keystore folder: " + keystore_file.parent_file.canonical_path
      end

      keytool_args = ["-genkey", 
        "-alias", "localhost", 
        "-dname", "CN=localhost, OU=Trinidad, O=Trinidad, C=ES", 
        "-keyalg", "RSA",
        "-validity", "365", 
        "-storepass", "key", 
        "-keystore", config[:ssl][:keystore], 
        "-storepass", config[:ssl][:keystorePass],
        "-keypass", config[:ssl][:keystorePass]]

      Trinidad::Tomcat::KeyTool.main(keytool_args.to_java(:string))
    end

    def start
      @tomcat.start
      @tomcat.getServer().await
    end

    private

    def add_default_web_app!(config)
      unless (config.has_key?(:web_apps))
        default_app = {
          :context_path => config[:context_path] || '/',
          :web_app_dir => config[:web_app_dir] || Dir.pwd
        }
        default_app[:rackup] = config[:rackup] if (config.has_key?(:rackup))

        config[:web_apps] = { :default => default_app }
      end
    end

  end
end
