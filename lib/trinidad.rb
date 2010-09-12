$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require "java"
require 'rubygems'

require 'jruby-rack'
require JRubyJars.jruby_rack_jar_path

gem 'trinidad_jars'

require 'trinidad/core_ext'

require 'trinidad/extensions'
require 'trinidad/command_line_parser'
require 'trinidad/jars'
require 'trinidad/server'
require 'trinidad/web_app_lifecycle_listener'
require 'trinidad/web_app'
require 'trinidad/rails_web_app'
require 'trinidad/rackup_web_app'


module Trinidad
  VERSION = File.read(File.expand_path('../../VERSION', __FILE__)).chomp
end
