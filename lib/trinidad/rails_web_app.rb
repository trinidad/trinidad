module Trinidad
  class RailsWebApp < WebApp

    def add_init_params
      super
      @context.addParameter('rails.env', environment.to_s) unless @context.findParameter('rails.env')
      @context.addParameter('rails.root', '/') unless @context.findParameter('rails.root')
    end

    def context_listener
      'org.jruby.rack.rails.RailsServletContextListener'
    end
  end
end
