module Trinidad
  module Extensions
    def self.configure_webapp_extensions(extensions, tomcat, app_context)
      if extensions
        extensions.each do |name, options|
          extension(name, 'WebAppExtension', options).configure(tomcat, app_context)
        end
      end
    end

    def self.configure_server_extensions(extensions, tomcat)
      if extensions
        extensions.each do |name, options|
          extension = extension(name, 'ServerExtension', options)
          configured_tomcat = extension.configure(tomcat)
          tomcat = configured_tomcat if extension.override_tomcat?
        end
      end
      tomcat
    end

    def self.configure_options_extensions(extensions, parser, default_options)
      if extensions
        extensions.each do |name, options|
          extension(name, 'OptionsExtension', options).configure(parser, default_options)
        end
      end
    end

    def self.extension(name, type, options)
      class_name = (name.to_s.camelize << type).to_sym
      load_extension(name) unless const_defined?(class_name)
      const_get(class_name).new(options)
    end

    def self.load_extension(name)
      require "trinidad_#{name}_extension"
    end

    class Extension
      def initialize(options = {})
        @options = options ? options.dup : {}
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

      def override_tomcat?; false; end # hack to allow override the tomcat's instance, it should be a better way
    end

    class OptionsExtension < Extension
      def configure(parser, default_options)
        raise NotImplementedError, "#{self.class}#configure not implemented"
      end
    end
  end
end
