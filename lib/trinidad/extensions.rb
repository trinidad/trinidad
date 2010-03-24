module Trinidad
  module Extensions
    def extensions
      @extensions ||= begin
        gems = Gem::GemPathSearcher.new.find_all("trinidad-*-extension").map {|gem| gem.name }
        extensions = gems.uniq.map {|e| Extension.new(e) }
        extensions = extensions.map {|e| [e.ext_name, e]}.flatten

        Hash[*extensions]
      end
    end

    def command_line_parser_extensions
      @parser_extensions ||= extensions.values.select {|e| e.options_addon? }
    end

    def server_extensions
      @server_extensions ||= extensions.values.select {|e| e.server_addon? }      
    end

    def webapp_extensions
      @webapp_extensions ||= extensions.values.select {|e| e.webapp_addon? }
    end

    def configure_parser_extensions(opts_parser, default_options)
      command_line_parser_extensions.each do |extension|
        extension.configure(:options, opts_parser, default_options)
      end
    end

    def configure_server_extensions(tomcat, config)
      server_extensions.each do |extension|
        extension.configure(:server, tomcat, config)
      end
    end

    def configure_webapp_extensions(app_context, global_config, app_config)
      webapp_extensions.each do |extension|
        extension.configure(:webapp, app_context, global_config, app_config)
      end
    end

    def configure_extension_by_name_and_type(name, type, *args)
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
        @name = name 
        @ext_name = @name.gsub(/trinidad(?:_|-)(.+)(?:_|-)extension/, '\1')
        @addons = {}
      end

      def configure(type, *args)
        addon = load_addon(type)
        addon.new.configure(args) if addon
      end

      def addon(type)
        load_addon(type)
      end

      def options_addon?
        !load_addon(:options).nil?
      end

      def server_addon?
        !load_addon(:server).nil?
      end

      def webapp_addon?
        !load_addon(:webapp).nil?
      end

      private
      def load_addon(type)
        @addons[type] ||= begin
          require @name
          class_name = "#{@ext_name.camelize}#{TYPES[type]}"

          Trinidad.const_get(class_name) rescue nil
        end
      end
    end
  end
end
