require 'trinidad/lifecycle/base'
require 'trinidad/lifecycle/web_app/shared'

module Trinidad
  module Lifecycle
    module WebApp
      class War < Base
        include Shared
        
        def before_init(event)
          # NOTE: esp. important for .war applications that the name matches the path
          # to work-around ProxyDirContext constructor's `contextPath = contextName;`
          # @see {#adjust_context} also need to restore possible context name change!
          context = event.lifecycle
          context.name = context.path if context.name
          super
        end
        
        def configure(context)
          super # Shared#configure
          configure_class_loader(context)
        end
        
        protected
        
        def adjust_context(context)
          name = context.name
          super
        ensure # @see {#before_init}
          context.name = name
          # NOTE: mimics HostConfig#deploWAR and should be removed
          # once Lifecycle::Host inherits func from HostConfig ...
          # context_name = Trinidad::Tomcat::ContextName.new(name)
          # context.setName context_name.getName()
          # context.setPath context_name.getPath()
          # context.setWebappVersion context_name.getVersion()
          # context.setDocBase context_name.getBaseName() + '.war'
        end

        def configure_class_loader(context)
          class_loader = web_app.class_loader || JRuby.runtime.jruby_class_loader
          loader = Trinidad::Tomcat::WebappLoader.new(class_loader)
          loader.container = context
          context.loader = loader
        end

        def remove_defaults(context = nil)
          # NOTE: do not remove defaults (welcome files)
        end
        
      end
    end
    War = Trinidad::Lifecycle::WebApp::War # backwards compatibility
  end
end
