$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require "java"
require 'rubygems'

require 'trinidad/core_ext'

require 'trinidad/command_line_parser'
require 'trinidad/jars'
require 'trinidad/server'
require 'trinidad/web_app'
require 'trinidad/rails_web_app'
require 'trinidad/rackup_web_app'

module Trinidad
  TRINIDAD_LIBS = File.dirname(__FILE__) + "/../trinidad-libs" unless defined?(TRINIDAD_LIBS)
end
