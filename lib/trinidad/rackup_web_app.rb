module Trinidad
  class RackupWebApp < WebApp

    def init_params
      super
      add_parameter_unless_exist('rackup', rackup_script) if rackup
      @params
    end

    def context_listener; 'org.jruby.rack.RackServletContextListener'; end

    def rackup_script
      script = File.directory?(rackup) ? File.join(rackup, 'config.ru') : rackup
      File.read(File.join(web_app_dir, script))
    end
  end
end
