require File.expand_path('../../../spec_helper', File.dirname(__FILE__))
require 'fileutils'

describe Trinidad::Lifecycle::WebApp::War do
  
  before do
    @context = Trinidad::Tomcat::Tomcat.new.add_webapp('/', MOCK_WEB_APP_DIR)
    @listener = Trinidad::Lifecycle::WebApp::War.new(Trinidad::WebApp.new({}, {}))
  end

  it "configures the war classloader" do
    @listener.send :configure_class_loader, @context
    @context.loader.should_not be nil
  end

  it "should create the log directory under the WEB-INF directory" do
    begin
      Dir.mkdir('apps_base')
      Dir.mkdir('apps_base/foo')
      Dir.mkdir('apps_base/foo/WEB-INF')

      app = Trinidad::WarWebApp.new({}, {
        :context_path => '/foo.war',
        :web_app_dir => File.expand_path('apps_base/foo.war'),
        :log => 'INFO',
        :environment => 'test'
      })
      listener = Trinidad::Lifecycle::WebApp::War.new(app)
      listener.send :configure_logging, @context

      File.exist?('apps_base/foo/WEB-INF/log').should be true
    ensure
      FileUtils.rm_rf('apps_base')
    end
  end
  
end

describe "Trinidad::Lifecycle::War" do
  it "still works" do
    Trinidad::Lifecycle::War.should == Trinidad::Lifecycle::WebApp::War
  end
end
