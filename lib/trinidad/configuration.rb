module Trinidad
  class << self
    attr_accessor :configuration
  end

  def self.configure(options = {})
    self.configuration ||= Configuration.new(options)
    yield self.configuration if block_given?
    self.configuration
  end

  # test only purposes
  def self.cleanup
    self.configuration = nil
  end

  class Configuration
    attr_accessor :port, :address, :environment, :context_path, :libs_dir, :classes_dir,
                 :default_web_xml, :log, :jruby_min_runtimes, :jruby_max_runtimes,
                 :monitor, :http, :ajp, :ssl, :extensions, :apps_base, :web_apps, :web_app_dir,
                 :trap, :rackup, :servlet, :public, :hosts

    def initialize(options = {})
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

      options.symbolize!.each {|k, v| self[k] = v}
    end

    def [](name)
      respond_to?(name) ? send(name) : nil
    end

    def []=(name, value)
      send :"#{name}=", value if respond_to?(:"#{name}=")
    end

    def has_key?(name)
      instance_variable_defined?(name) rescue false
    end
    alias_method :key?, :has_key?
  end
end
