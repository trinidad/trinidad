module Trinidad
  module Extensions
  class FooWebAppExtension < WebAppExtension
    def configure(tomcat, app_context)
      @options
    end
  end

  class FooServerExtension < ServerExtension
    def configure(tomcat)
      @options
    end
  end
  end
end
