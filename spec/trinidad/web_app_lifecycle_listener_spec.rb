require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fakeapp'

include FakeApp

# adding accessor for tests
class Trinidad::WebAppLifecycleListener
  attr_accessor :context
end

import org.apache.catalina.Lifecycle

describe Trinidad::WebAppLifecycleListener do
  before do
    @mock = mock
    @mock.stubs(:type).returns(Lifecycle::BEFORE_START_EVENT)
    @mock.stubs(:lifecycle).returns(Trinidad::Tomcat::StandardContext.new)

    @tomcat = Trinidad::Tomcat::Tomcat.new
    @tomcat.host.app_base = Dir.pwd
  end

  after do
    rm_rf(File.expand_path('../../../log', __FILE__))
    rm_rf(File.join(MOCK_WEB_APP_DIR, 'log'))
  end

  it "ignores the event when it's not BEFORE_START_EVENT" do
    listener = Trinidad::WebAppLifecycleListener.new(nil)
    @mock.stubs(:type).returns(Lifecycle::BEFORE_STOP_EVENT)
    lambda {
      listener.lifecycleEvent(@mock)
    }.should_not raise_error
  end

  it "tries to initialize the context when the event is BEFORE_START_EVENT" do
    listener = Trinidad::WebAppLifecycleListener.new(nil)
    lambda {
      listener.lifecycleEvent(@mock)
    }.should raise_error
  end

  it "doesn't load a default web xml when the deployment descriptor is not provided" do
    listener = Trinidad::WebAppLifecycleListener.new(Trinidad::RailsWebApp.new({}, {}))
    listener.configure_deployment_descriptor.should be_nil
  end

  it "loads a default web xml when the deployment descriptor is provided" do
    FakeFS do
      create_rails_web_xml

      listener = web_app_listener({
        :web_app_dir => Dir.pwd,
        :default_web_xml => 'config/web.xml'
      })

      expected_xml = File.join(Dir.pwd, 'config/web.xml')
      listener.configure_deployment_descriptor.should == expected_xml
      listener.context.default_web_xml.should == expected_xml

      listener.context.find_lifecycle_listeners.
        map {|l| l.class.name }.should include('Java::OrgApacheCatalinaStartup::ContextConfig')
    end
  end

  it "adds the rack servlet and the mapping for /*" do
    listener = web_app_listener({})

    listener.configure_rack_servlet

    servlet = listener.context.find_child('RackServlet')
    servlet.should_not be_nil
    servlet.servlet_class.should == 'org.jruby.rack.RackServlet'

    listener.context.find_servlet_mapping('/*').should == 'RackServlet'
  end

  it "configures the rack context listener from the web app" do
    listener = Trinidad::WebAppLifecycleListener.new(Trinidad::RackupWebApp.new({}, {}))
    listener.context = Trinidad::Tomcat::StandardContext.new
    listener.configure_rack_listener

    listener.context.find_application_listeners.should include('org.jruby.rack.RackServletContextListener')
  end

  it "adds context parameters from the web app" do
    listener = web_app_listener({
      :jruby_min_runtimes => 1
    })
    listener.configure_init_params

    listener.context.find_parameter('jruby.min.runtimes').should == '1'
  end

  it "ignores parameters already present in the deployment descriptor" do
    listener = web_app_listener({
      :jruby_max_runtimes => 1,
      :web_app_dir => MOCK_WEB_APP_DIR,
      :default_web_xml => 'config/web.xml'
    })
    listener.init_defaults(@tomcat.add_webapp('/', Dir.pwd))

    listener.context.find_parameter('jruby.max.runtimes').should be_nil
    listener.context.start
    listener.context.find_parameter('jruby.max.runtimes').should == '8'
  end

  it "doesn't load classes into a jar when the libs directory is not present" do
    web_app = Trinidad::RailsWebApp.new({}, {})
    listener = Trinidad::WebAppLifecycleListener.new(web_app)
    listener.add_application_jars(web_app.class_loader)

    lambda {
      web_app.class_loader.find_class('org.ho.yaml.Yaml')
    }.should raise_error
  end

  it "loads classes into a jar when the libs directory is provided" do
    web_app = Trinidad::RailsWebApp.new({}, {
      :web_app_dir => MOCK_WEB_APP_DIR,
      :libs_dir => 'lib'
    })
    listener = Trinidad::WebAppLifecycleListener.new(web_app)
    listener.add_application_jars(web_app.class_loader)

    lambda {
      web_app.class_loader.find_class('org.ho.yaml.Yaml').should_not be_nil
    }.should_not raise_error
  end

  it "doesn't load java classes when the classes directory is not present" do
    web_app = Trinidad::RailsWebApp.new({}, {})
    listener = Trinidad::WebAppLifecycleListener.new(web_app)
    listener.add_application_java_classes(web_app.class_loader)

    lambda {
      web_app.class_loader.find_class('HelloTomcat')
    }.should raise_error
  end

  it "loads java classes when the classes directory is provided" do
    web_app = Trinidad::RailsWebApp.new({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :classes_dir => 'classes'
    }, {})
    listener = Trinidad::WebAppLifecycleListener.new(web_app)
    listener.add_application_java_classes(web_app.class_loader)

    lambda {
      web_app.class_loader.find_class('HelloTomcat').should_not be_nil
    }.should_not raise_error
  end

  it "creates a WebappLoader with the JRuby class loader" do
    listener = web_app_listener({})
    listener.configure_context_loader

    loader = listener.context.loader

    loader.should be_instance_of(Java::OrgApacheCatalinaLoader::WebappLoader)
  end

  it "loads the default application from the current directory using the rackup file if :web_apps is not present" do
    web_app = Trinidad::RackupWebApp.new({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :rackup => 'config.ru'
    }, {})
    listener = Trinidad::WebAppLifecycleListener.new(web_app)
    listener.context = Trinidad::Tomcat::StandardContext.new
    listener.configure_init_params

    listener.context.find_parameter('rackup.path').should == "config.ru"
  end

  it "creates the log file according with the environment if it doesn't exist" do
    configure_logging(nil)
    File.exist?(File.join(MOCK_WEB_APP_DIR, 'log', 'test.log')).should be_true
  end

  it "uses the specified log level when it's valid" do
    configure_logging('WARNING')

    logger = java.util.logging.Logger.get_logger("")
    logger.level.to_s.should == 'WARNING'
  end

  it "uses INFO as default log level when it's invalid" do
    configure_logging('FOO')

    logger = java.util.logging.Logger.get_logger("")
    logger.level.to_s.should == 'INFO'
  end

  it "configures application logging once" do
    listener = web_app_listener({
      :environment => 'test',
      :web_app_dir => MOCK_WEB_APP_DIR,
      :log => 'INFO'
    })

    logger = java.util.logging.Logger.get_logger("")

    current_handlers = logger.handlers.size
    listener.configure_logging
    logger.handlers.should have(current_handlers + 1).handlers

    listener.configure_logging
    logger.handlers.should have(current_handlers + 1).handlers
  end

  def configure_logging(level)
    listener = web_app_listener({
      :environment => 'test',
      :web_app_dir => MOCK_WEB_APP_DIR,
      :log => level
    })
    listener.configure_logging
  end

  def web_app_listener(config)
    web_app = Trinidad::RailsWebApp.new(config, {})
    listener = Trinidad::WebAppLifecycleListener.new(web_app)
    listener.context = Trinidad::Tomcat::StandardContext.new
    listener
  end
end
