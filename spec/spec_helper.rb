begin
  require 'rspec'
rescue LoadError => e
  require('rubygems') && retry
  raise e
end

require 'fileutils'

RSpec.configure do |config|
  config.mock_with :mocha
  config.backtrace_clean_patterns = [
    #/org\/jruby.*?\.java$/,
    /spec\/spec_helper\.rb/,
    /lib\/rspec\/(core|expectations|matchers|mocks)/
  ]
  require File.expand_path('fake_files_helper', File.dirname(__FILE__))
  config.include FakeFilesHelper
end

$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../trinidad-libs')
$:.unshift(File.dirname(__FILE__) + '/fixtures')

require 'rack'
require 'trinidad'

MOCK_WEB_APP_DIR = File.join(File.dirname(__FILE__), 'web_app_mock')
RAILS_WEB_APP_DIR = File.join(File.dirname(__FILE__), 'web_app_rails')

# NOTE: disable listener backwards-compatibility in specs :
Trinidad::Lifecycle::WebApp::Default.class_eval do
  class_variable_get :@@_add_context_config # make sure it's there
  class_variable_set :@@_add_context_config, false
end

puts "running specs with TOMCAT_VERSION = #{Trinidad::TOMCAT_VERSION}"