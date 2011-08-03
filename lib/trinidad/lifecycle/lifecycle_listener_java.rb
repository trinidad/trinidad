module Trinidad
  module Lifecycle
    class Java < Base
      def configure_defaults(context)
        super
        configure_class_loader(context)
      end

      def configure_class_loader(context)
        loader = Trinidad::Tomcat::WebappLoader.new(@webapp.class_loader)
        loader.container = context
        context.loader = loader
      end
    end
  end
end
