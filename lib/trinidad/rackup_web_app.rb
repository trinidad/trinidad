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
      IO.read(File.join(@config[:web_app_dir], @config[:rackup]))
    end
  end
end
