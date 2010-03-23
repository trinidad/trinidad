module Trinidad
  module Extensions
    def extensions
      gems = Gem::GemPathSearcher.new.find_all("trinidad-*-extension").map {|gem| gem.name }
      extensions = gems.uniq.map {|e| Extension.new(e) }
      extensions = extensions.map {|e| [e.ext_name, e]}.flatten

      @extensions ||= Hash[*extensions]
    end

    def command_line_parser_extensions
      @parser_extensions ||= extensions.values.select {|e| !e.options_addon.nil? }
    end

    def server_extensions
      @server_extensions ||= extensions.values.select {|e| !e.server_addon.nil? }      
    end

    def webapp_extensions
      @webapp_extensions ||= extensions.values.select {|e| !e.webapp_addon.nil? }
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

    def configure_extension_by_name_and_type(name, type, *args)
      p extensions.inspect
      raise "unknown Trinidad extension: #{name}" unless extensions[name]
      extensions[name].configure(type, args)
    end

    class Extension
      attr_reader :name, :ext_name
      TYPES = {
        :options => 'OptionsAddon',
        :server  => 'ServerAddon',
        :webapp  => 'WebAppAddon'
      }

      def initialize(name)
        @name = name.gsub(/-/, '_') 
        @ext_name = @name.gsub(/trinidad_(.+)_extension/, '\1')
        @addons = {}
      end

      def configure(type, *args)
        @addons[type].configure(args) if @addons[type]
      end

      def options_addon
        load_addon(:options)
      end

      def server_addon
        load_addon(:server)
      end

      def webapp_addon
        load_addon(:webapp)
      end

      private
      def load_addon(type)
        require @name
        class_name = "#{@ext_name.camelize}#{TYPES[type]}"

        addon = Trinidad.const_get(class_name) rescue nil
        @addons[type] ||= addon
      end
    end
  end
end
