require 'java'

require 'jruby-rack'
require 'trinidad/jars'

require 'trinidad/version'

module Trinidad
  autoload :CLI, 'trinidad/cli'
end

require 'trinidad/helpers'
require 'trinidad/configuration'
require 'trinidad/extensions'
require 'trinidad/logging'
require 'trinidad/server'
require 'trinidad/web_app'
require 'trinidad/lifecycle/base'
require 'trinidad/lifecycle/host'
require 'trinidad/lifecycle/web_app/shared'
require 'trinidad/lifecycle/web_app/default'
require 'trinidad/lifecycle/web_app/war'
