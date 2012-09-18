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
      config = config_file(options[:root_dir] || options[:web_app_dir])
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

    DEFAULT_CONFIG_FILE = 'config/trinidad.{yml,rb}'
    
    def config_file(base_dir = nil)
      base_dir ||= Dir.pwd
      if @config_file.nil? # false means do not use no config file
        Dir.glob(File.join(base_dir, DEFAULT_CONFIG_FILE)).first
      else
        @config_file && File.expand_path(@config_file, base_dir)
      end
    end
    
    attr_writer :config_file
    
    def options_parser
      require 'optparse'
      @parser ||= OptionParser.new do |opts|
        opts.banner = 'Usage: trinidad [server options]'
        opts.separator ''

        opts.on('-d', '--dir ROOT_DIR', 'web application root directory',
          "default: current working directory") do |dir|
          default_options[:root_dir] = dir
        end

        opts.on('-e', '--env ENVIRONMENT', 'rack (rails) environment', 
          "default: #{default(:environment)}") do |env|
          default_options[:environment] = env
        end
        
        opts.on('-r', '--rackup [RACKUP_FILE]', 'rackup configuration file',
          "default: config.ru") do |rackup|
          default_options[:rackup] = rackup || 'config.ru'
        end

        opts.on('--public', '--public PUBLIC_DIR', 'web application public root', 
          "default: #{default(:public)}") do |public|
          default_options[:public] = public
        end
        
        opts.on('-c', '--context CONTEXT_PATH', 'application context path',
          "default: #{default(:context_path)}") do |path|
          default_options[:context_path] = path
        end
        
        opts.on('--monitor', '--monitor MONITOR_FILE', 'monitor for application re-deploys', 
          "default: tmp/restart.txt") do |monitor|
          default_options[:monitor] = monitor
        end
        
        opts.on('-t', '--threadsafe', 'force thread-safe mode (use single runtime)') do
          default_options[:jruby_min_runtimes] = 1
          default_options[:jruby_max_runtimes] = 1
        end
        
        opts.on('--runtimes MIN:MAX', 'use given number of min/max jruby runtimes', 
          "default: #{default(:jruby_min_runtimes)}:#{default(:jruby_max_runtimes)}") do 
          |min_max| min, max = min_max.split(':')
          default_options[:jruby_min_runtimes] = min.to_i if min
          default_options[:jruby_max_runtimes] = max.to_i if max
        end
        
        opts.on('-f', '--config [CONFIG_FILE]', 'configuration file',
          "default: #{DEFAULT_CONFIG_FILE}") do |file|
          self.config_file = file
        end
        
        opts.on('--address', '--address ADDRESS', 'host address', 
          "default: #{default(:address)}") do |address|
          default_options[:address] = address
        end
        
        opts.on('-p', '--port PORT', 'port to bind to', 
          "default: #{default(:port)}") do |port| 
          default_options[:port] = port
        end

        opts.on('-s', '--ssl [SSL_PORT]', 'enable secure socket layout',
          "default port: 8443") do |port|
          default_options[:ssl] = { :port => (port || 8443).to_i }
        end

        opts.on('-a', '--ajp [AJP_PORT]', 'enable the AJP web protocol',
          "default port: 8009") do |port|
          default_options[:ajp] = { :port => (port || 8009).to_i }
        end

        opts.on('--java_lib LIB_DIR', '--lib LIB_DIR (deprecated use --java_lib)', 
          'contains .jar files used by the app',
          "default: #{default(:java_lib)}") do |lib|
          default_options[:java_lib] = lib
        end

        opts.on('--java_classes CLASSES_DIR', '--classes CLASSES_DIR (deprecated use --java_classes)', 
          'contains java classes used by the app',
          "default: #{default_java_classes}") do |classes|
          default_options[:java_classes] = classes
        end

        opts.on('-l', '--load EXTENSION_NAMES', Array, 'load options for extensions') do |ext_names|
          ext_names.each do |ext|
            Trinidad::Extensions.configure_options_extensions({ ext => {} }, opts, default_options)
          end
        end

        opts.on('--apps_base APPS_BASE_DIR', '--apps APPS_BASE_DIR (deprecated use --apps_base)', 
          'set applications base directory') do |apps_base|
          default_options[:apps_base] = apps_base
        end
        
        opts.on('-g', '--log LEVEL', 'set logging level') do |log|
          default_options[:log] = log
        end
        
        opts.on('-v', '--version', 'show server version') do
          puts "Trinidad #{Trinidad::VERSION} (Tomcat #{Trinidad::TOMCAT_VERSION})"
          exit
        end
        
        opts.on('-h', '--help', 'display this help') do
          puts opts
          exit
        end
      end
    end
    
    private
    
    def default(key)
      default_options[key] || Configuration::DEFAULTS[key]
    end
    
    def default_java_classes
      default(:java_classes) || 
        ( default(:java_lib) && File.join(default(:java_lib), 'classes') )
    end
    
  end
end
