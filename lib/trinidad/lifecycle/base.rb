module Trinidad
  module Lifecycle
    # Trinidad lifecycle listener (generic) base class.
    # Allows hooking into the container's lifecycle using the provided methods.
    class Base

      include Trinidad::Tomcat::LifecycleListener

      # @private
      EVENTS = Trinidad::Tomcat::Lifecycle

      # The base implementation simply routes events to correspondig methods.
      #
      # http://tomcat.apache.org/tomcat-7.0-doc/api/org/apache/catalina/Lifecycle.html
      # http://tomcat.apache.org/tomcat-7.0-doc/api/org/apache/catalina/LifecycleListener.html
      def lifecycleEvent(event)
        case event.type
        when EVENTS::BEFORE_INIT_EVENT then
          before_init(event)
        when EVENTS::AFTER_INIT_EVENT then
          after_init(event)
        when EVENTS::BEFORE_START_EVENT then
          before_start(event)
        when EVENTS::CONFIGURE_START_EVENT then
          configure_start(event)
        when EVENTS::START_EVENT then
          start(event)
        when EVENTS::AFTER_START_EVENT then
          after_start(event)
        when EVENTS::BEFORE_STOP_EVENT then
          before_stop(event)
        when EVENTS::STOP_EVENT then
          stop(event)
        when EVENTS::CONFIGURE_STOP_EVENT then
          configure_stop(event)
        when EVENTS::AFTER_STOP_EVENT then
          after_stop(event)
        when EVENTS::BEFORE_DESTROY_EVENT then
          before_destroy(event)
        when EVENTS::AFTER_DESTROY_EVENT then
          after_destroy(event)
        when EVENTS::PERIODIC_EVENT then
          periodic(event)
        else
          raise "unsupported event.type = #{event.type}"
        end
      end

      # Event hook methods for a more Ruby-ish API :

      def before_init(event); end
      def after_init(event); end

      def before_start(event); end
      def configure_start(event); end
      def start(event); end
      def after_start(event); end

      def before_stop(event); end
      def stop(event); end
      def configure_stop(event); end
      def after_stop(event); end

      def before_destroy(event); end
      def after_destroy(event); end

      def periodic(event); end

    end
  end
end
