module Trinidad
  class RackupWebApp < WebApp

    def add_init_params
      super
      @context.addParameter('rackup', rackup_script) unless @context.findParameter('rackup')
    end    

    def context_listener
      'org.jruby.rack.RackServletContextListener'
    end

    def rackup_script
      IO.read(File.join(@app[:web_app_dir], @app[:rackup]))
    end
  end
end
