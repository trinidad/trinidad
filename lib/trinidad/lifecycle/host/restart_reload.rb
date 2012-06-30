module Trinidad
  module Lifecycle
    # Restarts the very same context on reloads, request processing pauses.
    class Host::RestartReload

      def reload!(app_holder)
        app_holder.context.reload
        true # release the lock
      end

    end
  end
end
