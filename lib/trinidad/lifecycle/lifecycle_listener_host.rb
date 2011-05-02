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
        host = event.lifecycle

        case event.type
        when Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT
          init_monitors
        when Trinidad::Tomcat::Lifecycle::PERIODIC_EVENT
          check_monitors
        end
      end

      def init_monitors
        @contexts.each do |c|
          monitor = c[:monitor]
          opts = File.exist?(monitor) ? 'r' : 'w+'

          unless File.exist?(dir = File.dirname(monitor))
            Dir.mkdir dir
          end

          file = File.new(monitor, opts)
          c[:mtime] = file.mtime
        end
      end

      def check_monitors
        @contexts.each do |c|
          # double check monitor, capistrano removes it temporarily
          sleep(0.5) unless File.exist?(c[:monitor])
          next unless File.exist?(c[:monitor])

          if (mtime = File.mtime(c[:monitor])) > c[:mtime] && !c[:lock]
            c[:lock] = true
            c[:mtime] = mtime
            c[:context] = create_takeover(c)
            c[:context].start
          end
        end
      end

      def create_takeover(c)
        web_app = c[:app]
        old_context = c[:context]

        context = Trinidad::Tomcat::StandardContext.new
        context.name = rand.to_s
        context.path = old_context.path
        context.doc_base = web_app.web_app_dir

        context.add_lifecycle_listener Trinidad::Tomcat::Tomcat::DefaultWebXmlListener.new

        config = Trinidad::Tomcat::ContextConfig.new
        config.default_web_xml = 'org/apache/catalin/startup/NO_DEFAULT_XML'
        context.add_lifecycle_listener config

        Trinidad::Extensions.configure_webapp_extensions(web_app.extensions, @tomcat, context)

        context.add_lifecycle_listener(web_app.define_lifecycle)
        context.add_lifecycle_listener(Trinidad::Lifecycle::Takeover.new(c))

        old_context.parent.add_child context

        context
      end
    end
  end
end
