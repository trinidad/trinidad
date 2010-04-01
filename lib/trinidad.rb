$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require "java"
require 'rubygems'
gem 'trinidad_jars'

require 'trinidad/core_ext'

require 'trinidad/extensions'
require 'trinidad/command_line_parser'
require 'trinidad/jars'
require 'trinidad/server'
require 'trinidad/web_app'
require 'trinidad/rails_web_app'
require 'trinidad/rackup_web_app'

module Trinidad
end