module Trinidad
  module Extensions
    class FooWebAppExtension < WebAppExtension
      def configure(tomcat, app_context)
        app_context.doc_base = 'foo_app_extension' if app_context
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
          default_options[:foo] = true
        end
      end
    end
  end
end
