module Trinidad
  require 'optparse'

  class CommandLineParser
    attr_reader :default_options

    def self.parse(argv)
      CommandLineParser.new.parse!(argv)
    end

    def initialize
      @default_options = {
        :port => 3000,
        :environment => 'development',
        :context_path => '',
        :libs_dir => 'lib',
        :classes_dir => 'classes',
        :ssl_port => 8443,
        :ajp_port => 8009,
        :config => 'config/trinidad.yml'
      }
    end

    def parse!(argv)
      begin
        options_parser.parse!(argv)
      rescue OptionParser::InvalidOption => e
        p e, options_parser
        exit(1)
      end

      if default_options.has_key?(:config)
        require 'yaml'
        default_options[:config] = File.expand_path(default_options[:config], default_options[:web_app_dir] || Dir.pwd)

        if File.exist?(default_options[:config])
          config_options = YAML.load_file(default_options[:config])
          default_options.deep_merge!(config_options.symbolize!)
        end
      end

      default_options
    end

    def options_parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = 'Trinidad server default options:'
        opts.separator ''

        opts.on('-d', '--dir WEB_APP_DIRECTORY', 'Web app directory path',
            "default: #{Dir.pwd}") do |v|
          default_options[:web_app_dir] = v
        end

        opts.on('-e', '--env ENVIRONMENT', 'Rails environment',
            "default: #{default_options[:environment]}") do |v|
          default_options[:environment] = v
        end

        opts.on('-p', '--port PORT', 'Port to bind to',
            "default: #{default_options[:port]}") do |v|
          default_options[:port] = v
        end

        opts.on('-c', '--context CONTEXT_PATH', 'The application context path',
            "default: #{default_options[:context_path]}") do |v|
          default_options[:context_path] = v
        end

        opts.on('--lib', '--jars LIBS_DIR', 'Directory containing jars used by the application',
            "default: #{default_options[:libs_dir]}") do |v|
          default_options[:libs_dir] = v
        end

        opts.on('--classes', '--classes CLASSES_DIR', 'Directory containing classes used by the application',
            "default: #{default_options[:classes_dir]}") do |v|
          default_options[:classes_dir] = v
        end

        opts.on('-s', '--ssl [SSL_PORT]', 'Enable secure socket layout',
            "default port: #{default_options[:ssl_port]}") do |v|
          ssl_port = v.nil? ? default_options.delete(:ssl_port) : v.to_i
          default_options[:ssl] = {:port => ssl_port}
        end

        opts.on('-a', '--ajp [AJP_PORT]', 'Enable ajp connections',
            "default port: #{default_options[:ajp_port]}") do |v|
          ajp_port = v.nil? ? default_options.delete(:ajp_port) : v.to_i
          default_options[:ajp] = {:port => ajp_port}
        end

        opts.on('-f', '--config [CONFIG_FILE]', 'Configuration file',
            "default: #{default_options[:config]}") do |file|
          default_options[:config] = file unless file.nil?
        end

        opts.on('-r', '--rackup [RACKUP_FILE]', 'Rackup configuration file',
            'default: config.ru') do |v|
          default_options[:rackup] = v || 'config.ru'
        end

        opts.on('--public', '--public DIRECTORY', 'Public directory', 'default: public') do |v|
          default_options[:public] = v
        end

        opts.on('-t', '--threadsafe', 'Threadsafe mode') do
          default_options[:jruby_min_runtimes] = 1
          default_options[:jruby_max_runtimes] = 1
        end

        opts.on('--address', '--address ADDRESS', 'Trinidad host address', 'default: localhost') do |v|
          default_options[:address] = v
        end

        opts.on('-g', '--log LEVEL', 'Log level', 'default: INFO') do |v|
          default_options[:log] = v
        end

        opts.on('-v', '--version', 'display the current version') do
          puts "trinidad #{Trinidad::VERSION} (tomcat #{Trinidad::TOMCAT_VERSION})"
          exit
        end

        opts.on('-l', '--load EXTENSION_NAMES', Array, 'load options for extensions') do |ext_names|
          ext_names.each do |ext|
            Trinidad::Extensions.configure_options_extensions({ext => {}}, opts, default_options)
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
