require 'trinidad/lifecycle/base'
require 'trinidad/lifecycle/web_app/shared'

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
          super # Shared#configure
          configure_class_loader(context)
        end
        
        protected
        
        def configure_class_loader(context)
          class_loader = web_app.class_loader || JRuby.runtime.jruby_class_loader
          loader = Trinidad::Tomcat::WebappLoader.new(class_loader)
          loader.container = context
          context.loader = loader
        end

        def remove_defaults(context = nil)
          # NOTE: do not remove defaults (welcome files)
        end
        
        private

        def expand_war_app(context)
          unless File.exist?(context.doc_base)
            host = context.parent
            war_file = java.io.File.new(web_app.root_dir)
            war = java.net.URL.new("jar:#{war_file.toURI.toURL.toString}!/")
            path_name = File.basename(context.doc_base)

            Trinidad::Tomcat::ExpandWar.expand(host, war, path_name)
          end
        end
        
        def remove_war_app(context)
          require 'fileutils'
          FileUtils.rm_rf web_app.root_dir.gsub(/\.war$/, '')
        end
        
      end
    end
    War = Trinidad::Lifecycle::WebApp::War # backwards compatibility
  end
end
