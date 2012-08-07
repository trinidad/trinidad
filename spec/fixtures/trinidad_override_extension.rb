module Trinidad
  module Extensions
    class OverrideServerExtension < ServerExtension
      
      def configure(tomcat)
        TomcatWrapper.new(tomcat)
      end
      
      class TomcatWrapper
        
        def initialize(tomcat) 
          @tomcat = tomcat
        end
        
        def respond_to?(name)
          super || @tomcat.respond_to?(name)
        end
        
        def method_missing(name, *args, &block)
          if @tomcat.respond_to?(name)
            @tomcat.send(name, *args, &block)
          else
            super
          end
        end
        
      end
      
    end
  end
end
