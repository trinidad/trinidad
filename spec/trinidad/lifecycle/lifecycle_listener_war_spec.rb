require File.dirname(__FILE__) + '/../../spec_helper'

describe Trinidad::Lifecycle::War do
  before do
    @context = Trinidad::Tomcat::Tomcat.new.add_webapp('/', MOCK_WEB_APP_DIR)
    @listener = Trinidad::Lifecycle::War.new(Trinidad::WebApp.new({}, {}))
  end

  it "configures the war classloader" do
    @listener.configure_class_loader(@context)
    @context.loader.should_not be_nil
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
      listener = Trinidad::Lifecycle::War.new(app)
      listener.configure_logging

      File.exist?('apps_base/foo/WEB-INF/log').should be_true
    ensure
      require 'fileutils'
      FileUtils.rm_rf('apps_base')
    end
  end
end
