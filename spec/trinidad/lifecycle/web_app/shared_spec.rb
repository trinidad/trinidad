require File.expand_path('../../../spec_helper', File.dirname(__FILE__))
require 'fileutils'

describe Trinidad::Lifecycle::WebApp::Shared do
  
  ListenerImpl = Trinidad::Lifecycle::WebApp::Default
  
  before do
    @context = Trinidad::Tomcat::Tomcat.new.add_webapp('/', MOCK_WEB_APP_DIR)
    Trinidad::Tomcat::Tomcat.init_webapp_defaults(@context)

    @options = {
        :root_dir => MOCK_WEB_APP_DIR, :environment => 'test', :log => 'INFO'
    }
    @web_app = Trinidad::WebApp.create({}, @options)
    @listener = ListenerImpl.new(@web_app)
  end

  after do
    FileUtils.rm_rf(File.expand_path('../../../log', __FILE__))
    FileUtils.rm_rf(File.join(MOCK_WEB_APP_DIR, 'log'))
  end

  it "removes the context default configurations" do
    @listener.send :remove_defaults, @context

    @context.welcome_files.should have(0).files

    @context.find_child('jsp').should be nil

    @context.process_tlds.should be false
    @context.xml_validation.should be false
  end

  it "configures logging on configure" do
    @listener.expects(:configure_logging)
    @listener.configure(@context)
  end

  it "configures during before start" do
    @listener.expects(:configure).with(@context)
    type = org.apache.catalina.Lifecycle::BEFORE_START_EVENT
    event = org.apache.catalina.LifecycleEvent.new(@context, type, nil)
    @listener.lifecycleEvent(event)
  end

  it "sets up work dir on configure" do
    @listener.expects(:set_work_dir)
    @listener.configure(@context)
  end

  it "sets up work dir" do
    @listener.send :set_work_dir, @context
    @context.work_dir.should == "#{MOCK_WEB_APP_DIR}/tmp"
    @context.work_path.should == "#{MOCK_WEB_APP_DIR}/tmp"
  end
  
  private
  
  def configure_logging(level)
    @options[:log] = level
    @listener = ListenerImpl.new Trinidad::WebApp.new({}, @options)
    @listener.send :configure_logging, @context
  end
  
end
