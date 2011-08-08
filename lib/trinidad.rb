require 'java'
require 'rubygems'

require 'jruby-rack'

gem 'trinidad_jars'

require 'trinidad/core_ext'

require 'trinidad/extensions'
require 'trinidad/command_line_parser'
require 'trinidad/jars'
require 'trinidad/server'
require 'trinidad/log_formatter'
require 'trinidad/lifecycle/takeover'
require 'trinidad/lifecycle/lifecycle_listener_host'
require 'trinidad/lifecycle/lifecycle_listener_base'
require 'trinidad/lifecycle/lifecycle_listener_default'
require 'trinidad/lifecycle/lifecycle_listener_war'
require 'trinidad/lifecycle/lifecycle_listener_java'
require 'trinidad/web_app/base'
require 'trinidad/web_app/rack'
require 'trinidad/web_app/rails'
require 'trinidad/web_app/war'
require 'trinidad/web_app/java'

module Trinidad
  VERSION = '1.2.3'
end
