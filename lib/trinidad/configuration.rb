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
      options = Configuration.symbolize_options(options)
      args.each do |opts|
        opts = Configuration.symbolize_options(opts)
        options = Configuration.merge_options(options, opts)
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

    DEFAULTS = {
      :environment => 'development',
      :context_path => '', # / root path
      :public => 'public',
      :java_lib => 'lib/java',
      :default_web_xml => 'config/web.xml',
      :trap => true
    }

    def initialize(options = {})
      @config = DEFAULTS.clone
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
        java_lib java_classes default_web_xml
        jruby_min_runtimes jruby_max_runtimes jruby_compat_version
        rackup servlet rack_servlet default_servlet public hosts
        http ajp ssl https extensions
        apps_base web_apps web_app_dir
        monitor reload_strategy log trap }.each do |method|
      class_eval "def #{method}; self[:'#{method}']; end"
      class_eval "def #{method}=(value); self[:'#{method}'] = value; end"
    end
    # TODO deprecate servlet

    # @private
    def self.symbolize_options(options)
      Helpers.symbolize(options, true)
    end

    # @private
    def self.merge_options(target, current)
      Helpers.merge(target, current, true)
    end

    # @private
    def self.options_like?(object); Helpers.hash_like?(object) end

  end
end
