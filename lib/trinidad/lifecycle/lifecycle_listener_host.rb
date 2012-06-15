module Trinidad
  module Lifecycle

    class Host
      include Trinidad::Tomcat::LifecycleListener

      attr_reader :contexts

      def initialize(tomcat, *contexts)
        @tomcat = tomcat
        @contexts = contexts
      end

      def lifecycleEvent(event)
        case event.type
        when Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT
          init_monitors
        when Trinidad::Tomcat::Lifecycle::PERIODIC_EVENT
          check_monitors
        end
      end

      def init_monitors
        @contexts.each do |context|
          monitor = context[:monitor]
          opts = 'w+'
          if ! File.exist?(dir = File.dirname(monitor))
            Dir.mkdir dir
          elsif File.exist?(monitor)
            opts = 'r'
          end
          file = File.new(monitor, opts)
          context[:mtime] = file.mtime
        end
      end

      def check_monitors
        @contexts.each do |context|
          # double check monitor, capistrano removes it temporarily
          sleep(0.5) unless File.exist?(context[:monitor])
          next unless File.exist?(context[:monitor])

          if (mtime = File.mtime(context[:monitor])) > context[:mtime] && !context[:lock]
            context[:lock] = true
            context[:mtime] = mtime
            context[:context] = create_takeover(context)
            Thread.new { context[:context].start }
          end
        end
      end

      def create_takeover(context)
        web_app = context[:app]
        old_context = context[:context]

        context = Trinidad::Tomcat::StandardContext.new
        context.name = rand.to_s
        context.path = old_context.path
        context.doc_base = web_app.web_app_dir

        context.add_lifecycle_listener Trinidad::Tomcat::Tomcat::DefaultWebXmlListener.new

        config = Trinidad::Tomcat::ContextConfig.new
        config.default_web_xml = 'org/apache/catalina/startup/NO_DEFAULT_XML'
        context.add_lifecycle_listener config

        Trinidad::Extensions.configure_webapp_extensions(web_app.extensions, @tomcat, context)

        web_app.generate_class_loader
        context.add_lifecycle_listener(web_app.define_lifecycle)
        context.add_lifecycle_listener(Trinidad::Lifecycle::Takeover.new(context))

        old_context.parent.add_child context

        context
      end
    end
  end
end
