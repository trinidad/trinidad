module Trinidad
  module Extensions
    class OverrideTomcatServerExtension < ServerExtension
      def configure(tomcat)
        Trinidad::Tomcat::Tomcat.new
      end

      def override_tomcat?; true; end
    end
  end
end
