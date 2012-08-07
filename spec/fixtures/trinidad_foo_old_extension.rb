module Trinidad
  module Extensions
    
    class FooOldWebAppExtension < WebAppExtension
      def configure(tomcat, context)
        if tomcat && tomcat.is_a?(Trinidad::Tomcat::Tomcat)
          if context && context.is_a?(Trinidad::Tomcat::Context)
            context.doc_base = 'foo_old_web_app_extension'
          end
        end
      end
    end
    
  end
end
