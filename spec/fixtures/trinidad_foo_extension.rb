module Trinidad
  module Extensions
    class FooWebAppExtension < WebAppExtension
      def configure(tomcat, app_context)
        @options
      end
    end

    class FooServerExtension < ServerExtension
      def configure(tomcat)
        @options
      end
    end

    class FooOptionsExtension < OptionsExtension
      def configure(parser, default_options)
        parser.on('--foo') do
          default_options[:bar] = true
        end
      end
    end
  end
end
