module Trinidad
  module Extensions
    
    class FooWebAppExtension < WebAppExtension
      def configure(context)
        if context && context.is_a?(Trinidad::Tomcat::Context)
          context.doc_base = 'foo_web_app_extension'
        end
      end
    end

    class FooServerExtension < ServerExtension
      def configure(tomcat)
        if tomcat && tomcat.is_a?(Trinidad::Tomcat::Tomcat)
          options[:foo] = 'foo_server_extension'
        end
      end
    end

    class FooOptionsExtension < OptionsExtension
      def configure(parser, default_options)
        parser.on('--foo') do
          default_options[:foo] = true
        end
      end
    end
    
  end
end
