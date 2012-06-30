begin
  require 'rspec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'rspec'
end

require 'mocha'
RSpec.configure do |config|
  config.mock_with :mocha
end

$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../trinidad-libs')
$:.unshift(File.dirname(__FILE__) + '/fixtures')

require 'java'
require 'rack'
require 'trinidad'

MOCK_WEB_APP_DIR = File.join(File.dirname(__FILE__), 'web_app_mock')
RAILS_WEB_APP_DIR = File.join(File.dirname(__FILE__), 'web_app_rails')

require File.expand_path('trinidad/fakeapp', File.dirname(__FILE__))
