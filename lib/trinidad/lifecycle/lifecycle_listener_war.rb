module Trinidad
  module Lifecycle
    class War < Base
      def lifecycleEvent(event)
        case event.type
        when Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT
          expand_app(event.lifecycle)
        when Trinidad::Tomcat::Lifecycle::AFTER_STOP_EVENT
          destroy_expanded_app
        end
        super
      end

      def configure_defaults(context)
        super
        configure_class_loader(context)
      end

      def configure_class_loader(context)
        loader = Trinidad::Tomcat::WebappLoader.new(web_app.class_loader)
        loader.container = context
        context.loader = loader
      end

      def destroy_expanded_app
        require 'fileutils'
        FileUtils.rm_rf web_app.web_app_dir.gsub(/\.war$/, '')
      end

      def expand_app(context)
        if !File.exist?(context.doc_base)
          host = context.parent
          war_file = java.io.File.new(web_app.web_app_dir)
          war = java.net.URL.new("jar:" + war_file.toURI.toURL.to_s + "!/")
          path_name = File.basename(context.doc_base)

          Trinidad::Tomcat::ExpandWar.expand(host, war, path_name)
        end
      end
    end
  end
end
