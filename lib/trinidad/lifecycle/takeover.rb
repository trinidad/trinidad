module Trinidad
  module Lifecycle
    class Takeover
      include Trinidad::Tomcat::LifecycleListener
      def initialize(old)
        @old = old
      end

      def lifecycleEvent(event)
        if event.type == Trinidad::Tomcat::Lifecycle::AFTER_START_EVENT
          begin
            name = @old[:context].name

            @old[:context].stop
            @old[:context].destroy

            event.lifecycle.name = name
          ensure
            @old.delete(:lock)
          end
        end
      end
    end
  end
end
