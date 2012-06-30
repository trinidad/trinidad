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

      autoload :RestartReload, 'trinidad/lifecycle/host/restart_reload'
      autoload :RollingReload, 'trinidad/lifecycle/host/rolling_reload'
      
      RELOAD_STRATEGIES = {
        :default => :RestartReload,
        :restart => :RestartReload,
        :rolling => :RollingReload,
      }
      
      def reload_application!(app_holder)
        strategy = (app_holder.web_app.reload_strategy || :default).to_sym
        strategy = RELOAD_STRATEGIES[ strategy ]
        strategy = strategy ? self.class.const_get(strategy) : RestartReload
        strategy.instance_method(:initialize).arity != 0 ?
          strategy.new(server).reload!(app_holder) : strategy.new.reload!(app_holder)
      end
      
    end
  end
end
