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
          monitors = c[:monitor]
          monitors.each do |monitor|
            if File.directory?(monitor)
              mtime = File.mtime(monitor)
              c[:mtime] = c[:mtime].nil? || mtime > c[:mtime] ? mtime : c[:mtime]
            elsif !Trinidad::WebApp::DEFAULT_MONITORED_APP_DIRS.include?(monitor)
              # the guard clause above means that if any of the DEFAULT_MONITORED_APP_DIRS don't exist then
              # we aren't going to monitor them

              opts = File.exist?(monitor) ? 'r' : 'w+'

              unless File.exist?(dir = File.dirname(monitor))
                Dir.mkdir dir
              end

              file = File.new(monitor, opts)
              c[:mtime] = c[:mtime].nil? || file.mtime > c[:mtime] ? file.mtime : c[:mtime]
            end
          end
        end
      end

      def check_monitors
        @contexts.each do |c|
          monitors = c[:monitor]
          mtime = c[:mtime]
          monitors.each do |monitor|
            # double check monitor, capistrano removes it temporarily
            sleep(0.5) unless File.exist?(monitor)
            next unless File.exist?(monitor)

            mtime = File.directory?(monitor) ?
                Dir["#{monitor}/**/*"].inject(mtime) {|max,f| cur = File.mtime(f); cur > max ? cur : max} :
                File.mtime(monitor) 
          end

          if mtime > c[:mtime] && !c[:lock]
            c[:lock] = true
            c[:mtime] = mtime
            c[:context] = create_takeover(c)
            Thread.new { c[:context].start }
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
        config.default_web_xml = 'org/apache/catalina/startup/NO_DEFAULT_XML'
        context.add_lifecycle_listener config

        Trinidad::Extensions.configure_webapp_extensions(web_app.extensions, @tomcat, context)

        web_app.generate_class_loader
        context.add_lifecycle_listener(web_app.define_lifecycle)
        context.add_lifecycle_listener(Trinidad::Lifecycle::Takeover.new(c))

        old_context.parent.add_child context

        context
      end
    end
  end
end
