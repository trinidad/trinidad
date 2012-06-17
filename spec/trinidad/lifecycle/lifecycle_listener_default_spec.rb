require File.dirname(__FILE__) + '/../../spec_helper'
require File.dirname(__FILE__) + '/../fakeapp'

describe Trinidad::Lifecycle::Default do
  include FakeApp
  
  before do
    @mock = mock
    @mock.stubs(:type).returns(Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT)
    @mock.stubs(:lifecycle).returns(Trinidad::Tomcat::StandardContext.new)

    @tomcat = Trinidad::Tomcat::Tomcat.new
    @tomcat.host.app_base = Dir.pwd
    @context = Trinidad::Tomcat::StandardContext.new
  end

  it "ignores the event when it's not BEFORE_START_EVENT" do
    listener = Trinidad::Lifecycle::Default.new(nil)
    @mock.stubs(:type).returns(Trinidad::Tomcat::Lifecycle::BEFORE_STOP_EVENT)
    lambda {
      listener.lifecycleEvent(@mock)
    }.should_not raise_error
  end

  it "tries to initialize the context when the event is BEFORE_START_EVENT" do
    listener = Trinidad::Lifecycle::Default.new(nil)
    lambda {
      listener.lifecycleEvent(@mock)
    }.should raise_error
  end

  it "doesn't load a default web xml when the deployment descriptor is not provided" do
    listener = Trinidad::Lifecycle::Default.new(Trinidad::RailsWebApp.new({}, {}))
    listener.configure_deployment_descriptor(@context).should be_nil
  end

  it "loads a default web xml when the deployment descriptor is provided" do
    FakeFS do
      create_rails_web_xml

      listener = web_app_listener({
        :web_app_dir => Dir.pwd,
        :default_web_xml => 'config/web.xml'
      })

      expected_xml = File.join(Dir.pwd, 'config/web.xml')

      listener.configure_deployment_descriptor(@context).should == expected_xml

      @context.find_lifecycle_listeners.
        map {|l| l.class.name }.should include('Java::OrgApacheCatalinaStartup::ContextConfig')

      context_configs = @context.find_lifecycle_listeners.select do |listener|
        listener.class.name == 'Java::OrgApacheCatalinaStartup::ContextConfig'
      end
      context_configs.size.should == 1
      context_configs.first.default_web_xml.should == expected_xml
    end
  end

  it "adds the rack servlet and the mapping for /*" do
    listener = web_app_listener({})

    listener.configure_rack_servlet(@context)

    servlet = @context.find_child('RackServlet')
    servlet.should_not be_nil
    servlet.servlet_class.should == 'org.jruby.rack.RackServlet'

    @context.find_servlet_mapping('/*').should == 'RackServlet'
  end

  it "configures the rack context listener from the web app" do
    listener = Trinidad::Lifecycle::Default.new(Trinidad::RackupWebApp.new({}, {}))
    listener.configure_rack_listener(@context)

    @context.find_application_listeners.should include('org.jruby.rack.RackServletContextListener')
  end

  it "adds context parameters from the web app" do
    listener = web_app_listener({
      :jruby_min_runtimes => 1
    })
    listener.configure_init_params(@context)

    @context.find_parameter('jruby.min.runtimes').should == '1'
  end

  it "ignores parameters already present in the deployment descriptor" do
    listener = web_app_listener({
      :jruby_max_runtimes => 1,
      :web_app_dir => MOCK_WEB_APP_DIR,
      :default_web_xml => 'config/web.xml'
    })
    context = @tomcat.add_webapp('/', Dir.pwd)
    listener.configure_defaults(context)

    context.find_parameter('jruby.max.runtimes').should be_nil
    context.start
    context.find_parameter('jruby.max.runtimes').should == '8'
  end

  it "doesn't load classes into a jar when the libs directory is not present" do
    web_app = Trinidad::RailsWebApp.new({}, {})
    listener = Trinidad::Lifecycle::Default.new(web_app)
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
    listener = Trinidad::Lifecycle::Default.new(web_app)
    listener.add_application_jars(web_app.class_loader)

    lambda {
      web_app.class_loader.find_class('org.ho.yaml.Yaml').should_not be_nil
    }.should_not raise_error
  end

  it "doesn't load java classes when the classes directory is not present" do
    web_app = Trinidad::RailsWebApp.new({}, {})
    listener = Trinidad::Lifecycle::Default.new(web_app)
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
    listener = Trinidad::Lifecycle::Default.new(web_app)
    listener.add_application_java_classes(web_app.class_loader)

    lambda {
      web_app.class_loader.find_class('HelloTomcat').should_not be_nil
    }.should_not raise_error
  end

  it "creates a WebappLoader with the JRuby class loader" do
    listener = web_app_listener({})
    listener.configure_context_loader(@context)

    @context.loader.should be_instance_of(Java::OrgApacheCatalinaLoader::WebappLoader)
  end

  it "loads the default application from the current directory using the rackup file if :web_apps is not present" do
    web_app = Trinidad::RackupWebApp.new({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :rackup => 'config.ru'
    }, {})
    listener = Trinidad::Lifecycle::Default.new(web_app)
    listener.configure_init_params(@context)

    @context.find_parameter('rackup.path').should == "config.ru"
  end

  def web_app_listener(config)
    web_app = Trinidad::RailsWebApp.new(config, {})
    Trinidad::Lifecycle::Default.new(web_app)
  end
end
