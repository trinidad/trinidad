module Trinidad
  module Lifecycle
    # A host lifecycle listener - monitors deployed web apps.
    class Host < Base
      
      attr_reader :server, :app_holders
      alias_method :contexts, :app_holders # #deprecated (<= 1.3.5)

      # #server current server instance
      # #app_holders deployed web application holders
      def initialize(server, *app_holders)
        app_holders.map! do |app_holder|
          if app_holder.is_a?(Hash) # backwards compatibility
            Trinidad::WebApp::Holder.new(app_holder[:app], app_holder[:context])
          else
            app_holder
          end
        end
        @server, @app_holders = server, app_holders
      end
      
      # @see Trinidad::Lifecycle::Base#before_start
      def before_start(event)
        init_monitors
      end

      # @see Trinidad::Lifecycle::Base#periodic
      def periodic(event)
        check_monitors
      end

      def tomcat; @server.tomcat; end # for backwards compatibility
      
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
            app_holder.unlock if reload_application!(app_holder)
          end
        end
      end

      def reload_application!(app_holder)
        app_holder.context = takeover_application_context(app_holder)

        Thread.new do
          begin
            app_holder.context.start
          ensure
            app_holder.unlock
          end
        end
        false # not yet reloaded do not release lock
      end
      
      private
      
      def takeover_application_context(app_holder)
        web_app, old_context = app_holder.web_app, app_holder.context
        
        web_app.generate_class_loader # use new class loader for application
        no_host = org.apache.catalina.Host.impl {} # do not add to parent yet
        new_context = server.add_web_app(web_app, no_host)
        new_context.add_lifecycle_listener(Takeover.new(old_context))

        old_context.parent.add_child new_context # add to parent TODO starts!

        new_context
      end
      
      class Takeover < Base # :nodoc

        def initialize(context)
          @old_context = context
        end

        def after_start(event)
          new_context = event.lifecycle
          new_context.remove_lifecycle_listener(self) # GC old context

          @old_context.stop
          @old_context.destroy
          # NOTE: name might not be changed once added to a parent
          new_context.name = @old_context.name
          super
        end
        
      end
      
    end
  end
end
