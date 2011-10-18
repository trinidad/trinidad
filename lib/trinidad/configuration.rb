module Trinidad
  class << self
    attr_accessor :configuration
  end

  def self.configure(options = {})
    self.configuration ||= Configuration.new(options)
    yield configuration if block_given?
  end

  class Configuration
    attr_accessor :port, :address, :environment, :context_path, :libs_dir, :classes_dir,
                 :default_web_xml, :log, :jruby_min_runtimes, :jruby_max_runtimes,
                 :monitor, :http, :ajp, :ssl, :extensions, :apps_base, :web_apps, :web_app_dir,
                 :trap, :rackup, :servlet, :public

    def initialize(options = {})
      options.symbolize!

      @environment = 'development'
      @context_path = '/'
      @libs_dir = 'lib'
      @classes_dir = 'classes'
      @default_web_xml = 'config/web.xml'
      @port = 3000
      @jruby_min_runtimes = 1
      @jruby_max_runtimes = 5
      @address = 'localhost'
      @log = 'INFO'
      @trap = true
    end

    def [](name)
      respond_to?(name) ? send(name) : nil
    end

    def []=(name, value)
      send :"#{name}=", value
    end

    def has_key?(name)
      instance_variable_defined?(name) rescue false
    end
    alias_method :key?, :has_key?
  end
end
