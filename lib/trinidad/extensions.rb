module Trinidad
  module Extensions
    def self.configure_webapp_extensions(extensions, tomcat, app_context)
      if extensions
        extensions.each do |name, options|
          extension(name, 'WebAppExtension').new(options).configure(tomcat, app_context)
        end
      end
    end

    def self.configure_server_extensions(extensions, tomcat)
      if extensions
        extensions.each do |name, options|
          extension(name, 'ServerExtension').new(options).configure(tomcat)
        end
      end
    end

    def self.extension(name, type)
      class_name = (name.camelize << type).to_sym
      load_extension(name) unless const_defined?(class_name)
      const_get(class_name)
    end

    def self.load_extension(name)
      require "trinidad_#{name}_extension"
    end

    class Extension
      def initialize(options)
        @options = options.dup
      end
    end

    class WebAppExtension < Extension
      def configure(tomcat, app_context)
        raise NotImplementedError, "#{self.class}#configure not implemented"
      end
    end

    class ServerExtension < Extension
      def configure(tomcat)
        raise NotImplementedError, "#{self.class}#configure not implemented"
      end
    end
  end
end
