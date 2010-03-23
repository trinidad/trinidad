module Trinidad
  module Extensions
    def extensions
      gems = Gem::GemPathSearcher.new.find_all("trinidad-*-extension").map {|gem| gem.name }
      @extensions ||= gems.uniq.map {|e| Extension.new(e) }
    end

    def command_line_parser_extensions
      @parser_extensions ||= extensions.select {|e| !e.options_addon.nil? }
    end

    def server_extensions
      @server_extensions ||= extensions.select {|e| !e.server_addon.nil? }      
    end

    def webapp_extensions
      @webapp_extensions ||= extensions.select {|e| !e.webapp_addon.nil? }
    end

    def configure_parser_extensions(opts_parser, default_options)
      command_line_parser_extensions.each do |extension|
        extension.options_addon.configure(opts_parser, default_options)
      end
    end

    def configure_server_extensions(tomcat, config)
      server_extensions.each do |extension|
        extension.server_addon.configure(tomcat, config)
      end
    end

    def configure_webapp_extensions(app_context, global_config, app_config)
      webapp_extensions.each do |extension|
        extension.webapp_addon.configure(app_context, global_config, app_config)
      end
    end

    class Extension
      attr_reader :name, :options_addon, :server_addon, :webapp_addon

      def initialize(name)
        @name = name.gsub(/-/, '_') 
        require @name

        ext_name = @name.gsub(/trinidad_(.+)_extension/) {
          $1.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
        }

        @options_addon = Trinidad.const_get("#{ext_name}OptionsAddon") rescue nil
        @server_addon = Trinidad.const_get("#{ext_name}ServerAddon") rescue nil
        @webapp_addon = Trinidad.const_get("#{ext_name}WebAppAddon") rescue nil
      end
    end
  end
end
