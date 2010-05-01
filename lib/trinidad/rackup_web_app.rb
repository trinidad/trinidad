module Trinidad
  class RackupWebApp < WebApp

    def init_params
      super
      add_parameter_unless_exist 'rackup', rackup_script
      @params
    end

    def context_listener; 'org.jruby.rack.RackServletContextListener'; end

    def rackup_script
      File.read(File.join(@app_config[:web_app_dir], @app_config[:rackup]))
    end
  end
end
