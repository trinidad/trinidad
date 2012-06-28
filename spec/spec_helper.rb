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

def with_host_monitor
  tmp = File.expand_path('tmp', MOCK_WEB_APP_DIR)
  monitor = File.join(tmp, 'restart.txt')
  FileUtils.rm_rf(tmp) if File.exist?(tmp)

  yield
ensure
  FileUtils.rm_rf(tmp) if File.exist?(tmp)
end

require File.expand_path('trinidad/fakeapp', File.dirname(__FILE__))
