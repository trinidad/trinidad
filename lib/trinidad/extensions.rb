module Trinidad
  module Extensions

    def self.configure_options_extensions(extensions, parser, default_options)
      extensions.each do |name, options|
        if extension = extension(name, 'OptionsExtension', options)
          extension.configure(parser, default_options)
        end
      end if extensions
    end

    def self.configure_server_extensions(extensions, tomcat)
      extensions.each do |name, options|
        if extension = extension(name, 'ServerExtension', options)
          outcome = extension.configure(tomcat)
          if tomcat_like?(outcome) || extension.override_tomcat?
            tomcat = outcome
          end
        end
      end if extensions
      tomcat
    end

    def self.configure_webapp_extensions(extensions, tomcat, context)
      extensions.map do |name, options|
        next if options == false # allow to explicitly disable
        if extension = extension(name, 'WebAppExtension', options)
          extension.tomcat = tomcat
          if extension.method(:configure).arity == 2
            extension.configure(tomcat, context) # @deprecated old way
          else
            extension.configure(context)
          end
          extension
        end
      end if extensions
    end

    protected

    def self.extension(name, type, options)
      class_name = Helpers.camelize(name) << type; clazz = nil
      if ( const_defined?(class_name) rescue nil )
        clazz = const_get(class_name)
      else
        begin
          load_extension(name)
        rescue LoadError => e
          Helpers.warn("Failed to load the #{name.inspect} extension (#{e.message}) ")
        else
          clazz = ( const_get(class_name) if const_defined?(class_name) ) rescue nil
        end
      end
      clazz.new(options) if clazz # MyExtension.new(options)
    end

    def self.load_extension(name)
      require "trinidad_#{name}_extension"
    end

    private

    def self.tomcat_like?(tomcat)
      tomcat.respond_to?(:server) && tomcat.respond_to?(:start) && tomcat.respond_to?(:stop)
    end

    def self.camelize(string)
      Helpers.deprecate("Trinidad::Extensions.camelize use the camelize helper " <<
                        "available in your Extension")
      Helpers.camelize(string)
    end

    class Extension
      include Helpers; extend Helpers

      attr_reader :options

      def initialize(options = {})
        @options = options ? options.dup : {}
      end

      private

      # Hash#symbolize
      def symbolize(options, deep = false)
        Trinidad::Configuration.symbolize_options(options, deep)
      end

    end

    class WebAppExtension < Extension

      attr_accessor :tomcat

      def configure(context)
        raise NotImplementedError, "#{self.class.name}#configure(context) not implemented"
      end

    end

    class ServerExtension < Extension

      def configure(tomcat)
        raise NotImplementedError, "#{self.class.name}#configure(tomcat) not implemented"
      end

      # #deprecated override tomcat by returning it from #configure
      def override_tomcat?; false; end

    end

    class OptionsExtension < Extension

      def configure(parser, default_options)
        raise NotImplementedError, "#{self.class.name}#configure(parser, default_options) not implemented"
      end

    end

  end
end
