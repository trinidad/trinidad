module Trinidad
  class CommandLineParser

    def self.parse(argv)
      CommandLineParser.new.parse!(argv)
    end

    def self.load(options = {})
      CommandLineParser.new.load!(options)
    end
    
    attr_reader :default_options
    
    def initialize
      @default_options = {}
    end

    # Parse the arguments and return the loaded Trinidad configuration.
    def parse!(argv)
      begin
        options_parser.parse!(argv)
      rescue OptionParser::InvalidOption => e
        p e, options_parser
        exit(1)
      end

      load!(default_options)
    end

    # Load the configuration from the given options and return it.
    def load!(options)
      config = config_file(options[:web_app_dir])
      if config && File.exist?(config)
        if yaml = (File.extname(config) == '.yml')
          require 'yaml'; require 'erb'
          config_options = YAML.load(ERB.new(File.read(config)).result(binding))
        end
        # NOTE: provided options should override configuration values :
        Trinidad.configure(config_options, options) do
          load config unless yaml # if not .yml assume it's ruby (.rb)
        end
      else
        Trinidad.configure(options)
      end
    end
    alias_method :load_configuration, :load!

    def config_file(base_dir = nil)
      base_dir ||= Dir.pwd
      if @config_file.nil? # false means do not use no config file
        Dir.glob(File.join(base_dir, 'config', 'trinidad.{yml,rb}')).first
      else
        @config_file && File.expand_path(@config_file, base_dir)
      end
    end
    
    attr_writer :config_file
    
    def options_parser
      require 'optparse'
      @parser ||= OptionParser.new do |opts|
        opts.banner = 'Trinidad server default options:'
        opts.separator ''

        opts.on('-d', '--dir WEB_APP_DIRECTORY', 'web app directory path',
            "default: #{Dir.pwd}") do |dir|
          default_options[:web_app_dir] = dir
        end

        opts.on('-e', '--env ENVIRONMENT', '(rails) environment',
            "default: #{default_options[:environment]}") do |env|
          default_options[:environment] = env
        end

        opts.on('-p', '--port PORT', 'port to bind to',
            "default: #{default_options[:port]}") do |port|
          default_options[:port] = port
        end

        opts.on('-c', '--context CONTEXT_PATH', 'application context path',
            "default: #{default_options[:context_path]}") do |path|
          default_options[:context_path] = path
        end

        opts.on('--lib', '--jars LIBS_DIR', 'directory containing java jars used by the application',
            "default: #{default_options[:libs_dir]}") do |dir|
          default_options[:libs_dir] = dir
        end

        opts.on('--classes', '--classes CLASSES_DIR', 'directory containing java classes used by the application',
            "default: #{default_options[:classes_dir]}") do |dir|
          default_options[:classes_dir] = dir
        end

        opts.on('-s', '--ssl [SSL_PORT]', 'enable secure socket layout',
            "default port: 8443") do |port|
          default_options[:ssl] = { :port => (port || 8443).to_i }
        end

        opts.on('-a', '--ajp [AJP_PORT]', 'enable ajp connections (deprecated)',
            "default port: 8009") do |port|
          default_options[:ajp] = { :port => (port || 8009).to_i }
        end

        opts.on('-f', '--config [CONFIG_FILE]', 'configuration file',
            "default: config/trinidad.{yml,rb}") do |file|
          self.config_file = file
        end

        opts.on('-r', '--rackup [RACKUP_FILE]', 'rackup configuration file',
            'default: config.ru') do |rackup|
          default_options[:rackup] = rackup || 'config.ru'
        end

        opts.on('--public', '--public DIRECTORY', 'public directory', 'default: public') do |public|
          default_options[:public] = public
        end

        opts.on('-t', '--threadsafe', 'force thread-safe mode') do
          default_options[:jruby_min_runtimes] = 1
          default_options[:jruby_max_runtimes] = 1
        end

        opts.on('--address', '--address ADDRESS', 'host address', 'default: localhost') do |address|
          default_options[:address] = address
        end

        opts.on('-g', '--log LEVEL', 'log level', 'default: INFO') do |log|
          default_options[:log] = log
        end

        opts.on('-v', '--version', 'display the current version') do
          puts "trinidad #{Trinidad::VERSION} (tomcat #{Trinidad::TOMCAT_VERSION})"
          exit
        end

        opts.on('-l', '--load EXTENSION_NAMES', Array, 'load options for extensions') do |ext_names|
          ext_names.each do |ext|
            Trinidad::Extensions.configure_options_extensions({ ext => {} }, opts, default_options)
          end
        end

        opts.on('--apps', '--apps APPS_BASE_DIR', 'applications base directory') do |path|
          default_options[:apps_base] = path
        end

        opts.on('--monitor' '--monitor MONITOR_FILE', 'monitor file for hot deployments') do |monitor|
          default_options[:monitor] = monitor
        end
        
        opts.on('-h', '--help', 'display the help') do
          puts opts
          exit
        end
      end
    end
    
  end
end
