require 'trinidad/lifecycle/base'

module Trinidad
  module Lifecycle
    # Host listener - monitors deployed applications
    # (re-invented HostConfig with Ruby/Rack semantics).
    class Host # TODO < Tomcat::HostConfig !

      include Trinidad::Tomcat::LifecycleListener

      EVENTS = Trinidad::Tomcat::Lifecycle

      attr_reader :server, :app_holders

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

      def contexts; @app_holders.map(&:context) end

      def lifecycleEvent(event)
        case event.type
        when EVENTS::BEFORE_START_EVENT then
          before_start(event)
        when EVENTS::START_EVENT then
          start(event)
        when EVENTS::STOP_EVENT then
          stop(event)
        when EVENTS::PERIODIC_EVENT then
          periodic(event)
        end
      end

      def before_start(event)
        init_monitors
      end

      def start(event); end

      def periodic(event)
        check_changes event.lifecycle
      end

      def stop(event); end

      protected

      def check_changes(host)
        check_monitors
      end

      def init_monitors
        app_holders.each do |app_holder|
          monitor = app_holder.monitor
          opts = 'w+'
          if ! File.exist?(dir = File.dirname(monitor)) # waR?
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
        new_args = []
        new_args << server if strategy.instance_method(:initialize).arity != 0
        strategy.new(*new_args).reload!(app_holder)
      end

    end
  end
end
