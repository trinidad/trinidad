module Trinidad
  module Extensions
    class BarOptionsExtension < OptionsExtension
      def configure(parser, default_options)
        default_options ||= {}
        default_options[:bar] = true
      end
    end
  end
end
