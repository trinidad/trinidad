module Trinidad
  module Extensions
    class MuuWebAppExtension < WebAppExtension
      def configure(context)
        context.doc_base = 'muu'
      end
    end
  end
end
