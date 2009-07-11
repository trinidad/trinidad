module Trinidad
  class Server
    
    attr_reader :tomcat
    
    @@defaults = {
      :environment => 'development',
      :context_path => '/',
      :libs_dir => 'lib',
      :classes_dir => 'classes',
      :default_web_xml => 'config/web.xml',
      :port => 3000,
      :jruby_min_runtimes => 1,
      :jruby_max_runtimes => 5,
      :ssl_keystore => 'ssl/keystore',
      :ssl_keystore_password => 'waduswadus'
    }
    
    def initialize(config = {})
      load_config(config)
      load_tomcat_server
      create_web_app      
    end
    
    def load_config(config)
      @config = {:web_app_dir => Dir.pwd}.merge!(@@defaults).merge!(config)
      
      @config[:ssl_keystore] = File.join(@config[:web_app_dir], @config[:ssl_keystore])
    end
    
    def load_tomcat_server
      @tomcat = Trinidad::Tomcat::Tomcat.new
      @tomcat.setPort(@config[:port].to_i)
      
      add_ssl_connector if ssl_enabled?
    end
    
    def create_web_app
      web_app = WebApp.new(@tomcat.addWebapp(@config[:context_path].to_s, @config[:web_app_dir]), @config)

      web_app.load_default_web_xml
      web_app.add_rack_filter
      web_app.add_context_loader
      web_app.add_init_params
      web_app.add_web_dir_resources
      
      web_app.add_rack_context_listener
    end
    
    def add_ssl_connector
      ssl_connector = Trinidad::Tomcat::Connector.new
  		ssl_connector.scheme = "https"
  		ssl_connector.secure = true
  		ssl_connector.port = @config[:ssl]
  		ssl_connector.setProperty("SSLEnabled","true")
  		ssl_connector.setProperty("keystore", @config[:ssl_keystore])
  		ssl_connector.setProperty("keystorePass", @config[:ssl_keystore_password])
  		
  		@tomcat.getService().addConnector(ssl_connector)
  		
  		create_default_keystore unless File.exist?(@config[:ssl_keystore])
    end
    
    def ssl_enabled?
      !@config[:ssl].nil? && @config[:ssl].is_a?(Fixnum)
    end
    
    def create_default_keystore
      keystore_file = java.io.File.new(@config[:ssl_keystore])
      
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
        "-keystore", @config[:ssl_keystore], 
        "-storepass", @config[:ssl_keystore_password],
        "-keypass", @config[:ssl_keystore_password]]
              
      Trinidad::Tomcat::KeyTool.main(keytool_args.to_java(:string))
    end

    def start
      @tomcat.start
      @tomcat.getServer().await
    end
  end
end