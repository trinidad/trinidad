module Trinidad
  module Lifecycle
    class War < Base
      def configure_defaults(context)
        super
        configure_class_loader(context)
        clean_context_configuration(context)
      end

      def configure_class_loader(context)
        loader = Trinidad::Tomcat::WebappLoader.new(@webapp.class_loader)
        loader.container = context
        context.loader = loader
      end

      def clean_context_configuration(context)
        config = context.find_lifecycle_listeners.select {|listener| listener.instance_of? Trinidad::Tomcat::ContextConfig }
        config.each { |c| context.remove_lifecycle_listener(c) }

        config = Trinidad::Tomcat::ContextConfig.new
        context.add_lifecycle_listener config
      end
    end
  end
end
