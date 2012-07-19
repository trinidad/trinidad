module Trinidad
  class << self
    attr_accessor :configuration
  end

  # Creates a new global configuration (unless already exists) and 
  # (deep) merges the current values using the provided options.
  def self.configure(*args)
    config = ( self.configuration ||= Configuration.new )
    args.compact!
    if options = args.shift
      options = Trinidad::Configuration.symbolize_options(options)
      args.each do |opts|
        opts = Trinidad::Configuration.symbolize_options(opts)
        options = Trinidad::Configuration.merge_options(options, opts)
      end
      config.update!(options)
    end
    
    yield config if block_given?
    config
  end

  # Forces a new global configuration using default and the provided options.
  def self.configure!(*args, &block)
    self.configuration = Configuration.new
    configure(*args, &block)
  end
  
  # Trinidad's (global) configuration instance.
  # Use Trinidad#configure to update and obtain the global instance or access 
  # the instance using Trinidad#configuration
  class Configuration
    
    def initialize(options = {})
      @config = {
        :port => 3000,
        :address => 'localhost', 
        :environment => 'development',
        :context_path => '/',
        :libs_dir => 'lib',
        :classes_dir => 'classes',
        :default_web_xml => 'config/web.xml',
        :jruby_min_runtimes => 1,
        :jruby_max_runtimes => 5,
        :log => 'INFO',
        :trap => true
      }
      update!(options)
    end

    def [](name) 
      @config[name.to_sym]
    end

    def []=(name, value)
      @config[name.to_sym] = value
    end

    def has_key?(name)
      @config.has_key?(name.to_sym)
    end
    alias_method :key?, :has_key?
    
    def keys
      @config.keys
    end
    
    def each(&block)
      @config.each(&block)
    end
    
    def update!(options)
      options.each do |key, value|
        self[key] = value.respond_to?(:strip) ? value.strip : value
      end
    end
    
    %w{ port address environment context_path
        libs_dir classes_dir default_web_xml
        jruby_min_runtimes jruby_max_runtimes
        rackup servlet public hosts
        http ajp ssl extensions
        apps_base web_apps web_app_dir
        monitor log trap }.each do |method|
      class_eval "def #{method}; self[:'#{method}']; end"
      class_eval "def #{method}=(value); self[:'#{method}'] = value; end"
    end
    
    # a Hash like #symbolize helper
    def self.symbolize_options(options, deep = true)
      new_options = options.class.new
      options.each do |key, value|    
        if deep && value.is_a?(Array)
          new_options[key.to_sym] = []
          value.each do |v|
            if options_like?(v)
              new_options[key.to_sym] << symbolize_options(v, deep) 
            else
              new_options[key.to_sym] << value
            end
          end
        elsif deep && options_like?(value)
          new_options[key.to_sym] = symbolize_options(value, deep)
        else
          new_options[key.to_sym] = value
        end
      end
      new_options
    end
    
    # a Hash like deep_merge helper
    def self.merge_options(target, current, deep = true)
      target_dup = target.dup
      current.keys.each do |key|
        target_dup[key] = 
          if deep && options_like?(target[key]) && options_like?(current[key])
            merge_options(target[key], current[key], deep)
          else
            current[key]
          end
      end
      target_dup
    end
    
    private
    def self.options_like?(object)
      object.is_a?(Hash) || 
        ( object.respond_to?(:keys) && object.respond_to?(:'[]') )
    end
    
  end
end
