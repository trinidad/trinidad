module Trinidad
  module Lifecycle
    module WebApp
      class War < Base
        include Shared
        
        def before_start(event)
          expand_war_app(event.lifecycle)
          super # Shared#before_start
        end
        
        def after_start(event)
          super
          remove_war_app(event.lifecycle)
        end
        
        def configure(context)
          super
          configure_class_loader(context)
        end

        protected
        
        def configure_class_loader(context)
          loader = Trinidad::Tomcat::WebappLoader.new(web_app.class_loader)
          loader.container = context
          context.loader = loader
        end

        private

        def expand_war_app(context)
          unless File.exist?(context.doc_base)
            host = context.parent
            war_file = java.io.File.new(web_app.web_app_dir)
            war = java.net.URL.new("jar:" + war_file.toURI.toURL.to_s + "!/")
            path_name = File.basename(context.doc_base)

            Trinidad::Tomcat::ExpandWar.expand(host, war, path_name)
          end
        end
        
        def remove_war_app(context)
          require 'fileutils'
          FileUtils.rm_rf web_app.web_app_dir.gsub(/\.war$/, '')
        end
        
      end
    end
    War = Trinidad::Lifecycle::WebApp::War # backwards compatibility
  end
end
