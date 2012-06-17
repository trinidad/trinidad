module Trinidad
  module Lifecycle
    class Host
      include Trinidad::Tomcat::LifecycleListener

      attr_reader :tomcat, :app_holders

      # #tomcat current tomcat instance
      # #app_holders deployed web application holders
      def initialize(tomcat, *app_holders)
        app_holders.map! do |app_holder|
          if app_holder.is_a?(Hash) # backwards compatibility
            WebApp::Holder.new(app_holder[:app], app_holder[:context])
          else
            app_holder
          end
        end
        @tomcat, @app_holders = tomcat, app_holders
      end
      
      def lifecycleEvent(event)
        case event.type
        when Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT
          init_monitors
        when Trinidad::Tomcat::Lifecycle::PERIODIC_EVENT
          check_monitors
        end
      end

      # #deprecated backwards (<= 1.3.5) compatibility
      alias_method :contexts, :app_holders
      
      protected
      
      def init_monitors
        app_holders.each do |app_holder|
          monitor = app_holder.monitor
          opts = 'w+'
          if ! File.exist?(dir = File.dirname(monitor))
            Dir.mkdir dir
          elsif File.exist?(monitor)
            opts = 'r'
          end
          File.open(monitor, opts) do |file|
            app_holder.monitor_mtime = file.mtime
          end
        end
      end

      def check_monitors
        app_holders.each do |app_holder|
          # double check monitor, capistrano removes it temporarily
          unless File.exist?(monitor = app_holder.monitor)
            sleep(0.5)
            next unless File.exist?(monitor)
          end
          
          mtime = File.mtime(monitor)
          if mtime > app_holder.monitor_mtime && app_holder.try_lock
            app_holder.monitor_mtime = mtime
            app_holder.context = takeover_app_context(app_holder)
            
            Thread.new do
              begin
                app_holder.context.start
              ensure
                app_holder.unlock
              end
            end
          end
        end
      end

      private
      
      def takeover_app_context(app_holder)
        web_app = app_holder.web_app
        old_context = app_holder.context
        new_context = Trinidad::Tomcat::StandardContext.new
        new_context.name = "#{old_context.name}-#{java.lang.System.currentTimeMillis}"
        new_context.path = old_context.path
        new_context.doc_base = web_app.web_app_dir

        new_context.add_lifecycle_listener Trinidad::Tomcat::Tomcat::DefaultWebXmlListener.new

        config = Trinidad::Tomcat::ContextConfig.new
        config.default_web_xml = 'org/apache/catalina/startup/NO_DEFAULT_XML'
        new_context.add_lifecycle_listener config

        Trinidad::Extensions.configure_webapp_extensions(web_app.extensions, tomcat, new_context)

        web_app.generate_class_loader
        new_context.add_lifecycle_listener(web_app.define_lifecycle)
        new_context.add_lifecycle_listener(Takeover.new(old_context))

        old_context.parent.add_child new_context

        new_context
      end
      
      class Takeover # :nodoc
        include Trinidad::Tomcat::LifecycleListener

        def initialize(context)
          @old_context = context
        end

        def lifecycleEvent(event)
          if event.type == Trinidad::Tomcat::Lifecycle::AFTER_START_EVENT
            @old_context.stop
            @old_context.destroy
            # event.lifecycle == the new context ...
            event.lifecycle.name = @old_context.name
          end
        end
      end
      
    end
  end
end
