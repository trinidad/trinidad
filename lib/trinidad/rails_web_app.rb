module Trinidad
  class RailsWebApp < WebApp

    def init_params
      super
      add_parameter_unless_exist 'rails.env', environment.to_s
      add_parameter_unless_exist 'rails.root', '/'
      @params
    end

    def context_listener; 'org.jruby.rack.rails.RailsServletContextListener'; end
    
  end
end