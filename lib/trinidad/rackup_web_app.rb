module Trinidad
  class RackupWebApp < WebApp

    def add_init_params
      super
      add_parameter_unless_exist('rackup', rackup_script)
    end

    def context_listener
      'org.jruby.rack.RackServletContextListener'
    end

    def rackup_script
      IO.read(File.join(@app[:web_app_dir], @app[:rackup]))
    end

    def provided_web_xml; 'rackup_web.xml'; end
  end
end
