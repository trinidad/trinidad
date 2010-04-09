module Trinidad
  require 'optparse'
  require 'yaml'
  
  class CommandLineParser

    def self.parse
      default_options = {
        :port => 3000,
        :environment => 'development',
        :context_path => '/',
        :libs_dir => 'lib',
        :classes_dir => 'classes',
        :config => 'config/tomcat.yml',
        :ssl_port => 8443,
        :ajp_port => 8009
      }
 
      parser = OptionParser.new do |opts|
        opts.banner = 'Trinidad server default options:'
        opts.separator ''

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
            "default: #{default_options[:config]}") do |v|
          default_options[:config] = v if v
          default_options.deep_merge! YAML.load_file(default_options[:config])
        end

        opts.on('-r', '--rackup [RACKUP_FILE]', 'Rackup configuration file',
            'default: config.ru') do |v|
          default_options[:rackup] = v || 'config.ru'  
        end

        opts.on('--public', '--public DIRECTORY', 'Public directory', 'default: public') do |v|
          default_options[:public] = v
        end

        opts.on('-v', '--version', 'display the current version') do
          puts File.read(File.join(File.dirname(__FILE__), '..', '..', 'VERSION')).chomp
          exit
        end

        opts.on('-h', '--help', 'display the help') do
          puts opts
          exit
        end

        opts.parse!(ARGV)
      end

      default_options
    end
  end
end
