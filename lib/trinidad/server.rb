module Trinidad
  JSystem = java.lang.System
  JContext = javax.naming.Context

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
        :jruby_max_runtimes => 5
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
      @tomcat.port = @config[:port].to_i
      @tomcat.base_dir = Dir.pwd
      @tomcat.host.app_base = Dir.pwd
      enable_naming

      add_ssl_connector if ssl_enabled?
      add_ajp_connector if ajp_enabled?

      @tomcat = Trinidad::Extensions.configure_server_extensions(@config[:extensions], @tomcat)
    end

    def create_web_apps
      @config[:web_apps].each do |name, app_config|
        app_config[:context_path] ||= (name.to_s == 'default' ? '/' : "/#{name.to_s}")
        app_config[:web_app_dir] ||= Dir.pwd

        app_context = @tomcat.addWebapp(app_config[:context_path], app_config[:web_app_dir])
        remove_defaults(app_context)

        web_app = WebApp.create(@config, app_config)

        Trinidad::Extensions.configure_webapp_extensions(web_app.extensions, @tomcat, app_context)
        app_context.add_lifecycle_listener(WebAppLifecycleListener.new(web_app).to_java)
      end
    end

    def add_service_connector(options, protocol = nil)
      connector = Trinidad::Tomcat::Connector.new(protocol)

      opts = options.dup

      connector.scheme = opts.delete(:scheme) if opts[:scheme]
      connector.secure = opts.delete(:secure) || false
      connector.port = opts.delete(:port).to_i

      opts.each do |key, value|
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
      keystore_file = java.io.File.new(config[:keystore])

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
        "-keystore", config[:keystore], 
        "-storepass", config[:keystorePass],
        "-keypass", config[:keystorePass]]

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

    def enable_naming
      @tomcat.getServer().addLifecycleListener(Trinidad::Tomcat::NamingContextListener.new)

      JSystem.setProperty("catalina.useNaming", "true")

      value = "org.apache.naming"
      old_value = JSystem.getProperty(JContext.URL_PKG_PREFIXES) || value

      value = value + ":" + old_value unless old_value.include?(value)
      JSystem.setProperty(JContext.URL_PKG_PREFIXES, value)

      value = JSystem.getProperty(JContext.INITIAL_CONTEXT_FACTORY)
      unless value
        JSystem.setProperty(JContext.INITIAL_CONTEXT_FACTORY, "org.apache.naming.java.javaURLContextFactory")
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
