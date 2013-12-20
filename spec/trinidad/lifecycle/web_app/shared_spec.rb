require File.expand_path('../../../spec_helper', File.dirname(__FILE__))
require 'fileutils'

describe Trinidad::Lifecycle::WebApp::Shared do

  ListenerImpl = Trinidad::Lifecycle::WebApp::Default

  before do
    @context = Trinidad::Tomcat.new.add_webapp('/', MOCK_WEB_APP_DIR)
    Trinidad::Tomcat.init_webapp_defaults(@context)

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
    @listener.expects(:adjust_context)
    @listener.configure(@context)
  end

  it "sets up work dir" do
    @listener.send :adjust_context, @context
    expect( @context.work_dir ).to eql "#{MOCK_WEB_APP_DIR}/tmp"
    expect( @context.work_path ).to eql "#{MOCK_WEB_APP_DIR}/tmp"
  end

  it "sets context name" do
    @web_app.expects(:context_name).at_least_once.returns 'foo'
    @listener.send :adjust_context, @context
    expect( @context.name ).to eql 'foo'
  end

  it "allows linking by default" do
    @listener.send :adjust_context, @context
    expect( @context.allow_linking).to be true
  end

  it "allows linking to be configured" do
    @web_app[:allow_linking] = false
    @listener.send :adjust_context, @context
    expect( @context.allow_linking).to be false
  end

  # this avoids naming errors when starting a new context with the same name :
  # Creation of the naming context failed:
  #   javax.naming.OperationNotSupportedException: Context is read only

  it "does not set the context name if it's 'similar'" do
    @web_app.expects(:context_name).at_least_once.returns 'foo'
    @context.name = "foo-1234567890"
    @listener.send :adjust_context, @context
    @context.name.should == 'foo-1234567890'
  end

  private

  def configure_logging(level)
    @options[:log] = level
    @listener = ListenerImpl.new Trinidad::WebApp.new({}, @options)
    @listener.send :configure_logging, @context
  end

end
