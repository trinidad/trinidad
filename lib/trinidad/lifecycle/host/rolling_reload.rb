require 'thread'

module Trinidad
  module Lifecycle
    # Rolls a new context that replaces the current one on reloads.
    class Host::RollingReload

      def initialize(server)
        @server = server
      end

      def reload!(app_holder)
        web_app, old_context = app_holder.web_app, app_holder.context
        logger = self.class.logger
        logger.info "Context with name [#{old_context.name}] has started rolling"

        web_app.reset! # force a new class loader + re-read state (from config)
        no_host = org.apache.catalina.Host.impl {} # do not add to parent yet
        new_context = @server.add_web_app(web_app, no_host)
        new_context.add_lifecycle_listener(takeover = Takeover.new(old_context))
        # Tomcat requires us to have unique names for its containers :
        new_context.name = "#{old_context.name}-#{java.lang.System.currentTimeMillis}"

        app_holder.context = new_context

        Thread.new do
          begin
            logger.debug "Starting a new Context for [#{new_context.path}]"
            old_context.parent.add_child new_context # NOTE: likely starts!
            
            new_context.start unless new_context.state_name =~ /START|STOP|FAILED/i
            
            if new_context.state_name =~ /STOP|FAILED/i
              logger.error("Context with name [#{old_context.name}] failed rolling")
              takeover.failed!(new_context)
            else
              logger.info "Context with name [#{old_context.name}] has completed rolling"
            end
          rescue => error
            e = org.jruby.exceptions.RaiseException.new(error)
            logger.error("Context with name [#{old_context.name}] failed rolling", e)
            takeover.failed!(new_context)
          rescue java.lang.Exception => e
            logger.error("Context with name [#{old_context.name}] failed rolling", e)
            takeover.failed!(new_context)
          ensure
            app_holder.unlock
          end
        end
        false # not yet reloaded do not release lock
      end

      def self.logger # log into the same location as context.reload does :
        Trinidad::Logging::LogFactory.getLog('org.apache.catalina.core.StandardContext')
      end

      class Takeover < Trinidad::Lifecycle::Base # :nodoc
        
        def initialize(context)
          @old_context = context
        end

        def after_start(event)
          new_context = event.lifecycle
          new_context.remove_lifecycle_listener(self) # GC old context

          logger.debug "Stoping the old Context for [#{@old_context.path}]"

          @old_context.stop
          @old_context.work_dir = nil # make sure it's not deleted
          @old_context.destroy
          # NOTE: name might not be changed once added to a parent
          new_context.name = @old_context.name
          super
        end

        def failed!(new_context)
          # NOTE: this will also likely destroy() the child - new context :
          @old_context.parent.remove_child new_context
          logger.info "Failed to start new Context for [#{@old_context.path}] " + 
                      "(check application logs) keeping the old one running ..."
          new_context.remove_lifecycle_listener(self)
        end
        
        private
        
        def logger
          Trinidad::Lifecycle::Host::RollingReload.logger
        end
        
      end

    end
  end
end
