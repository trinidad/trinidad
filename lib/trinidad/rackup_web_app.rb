module Trinidad
  class RackupWebApp < WebApp

    def init_params
      super
      if rackup_path = rackup
        rackup_path = File.join(rackup_path, 'config.ru') if File.directory?(rackup_path)
        add_parameter_unless_exist('rackup.path', rackup_path)
        add_parameter_unless_exist('rack.env', environment.to_s)
      end
      @params
    end

    def context_listener; 'org.jruby.rack.RackServletContextListener'; end
  end
end
