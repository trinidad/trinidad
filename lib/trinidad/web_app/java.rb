module Trinidad
  module WebApp
    class Java < Base
      def public_root
        ''
      end

      def define_lifecycle
        Trinidad::Lifecycle::Java.new(self)
      end
    end
  end

  JavaWebApp = WebApp::Java
end
