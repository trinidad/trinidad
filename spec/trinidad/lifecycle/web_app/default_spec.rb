require File.expand_path('../../../spec_helper', File.dirname(__FILE__))

describe Trinidad::Lifecycle::WebApp::Default do
  include FakeApp

  let(:tomcat) do
    tomcat = Trinidad::Tomcat::Tomcat.new
    tomcat.host.app_base = Dir.pwd
    tomcat
  end
  
  let(:context) { Trinidad::Tomcat::StandardContext.new }
  
  it "ignores the event when it's not BEFORE_START_EVENT" do
    mock = mock('event')
    mock.stubs(:type).returns(Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT)
    mock.stubs(:lifecycle).returns(Trinidad::Tomcat::StandardContext.new)
    
    listener = Trinidad::Lifecycle::WebApp::Default.new(nil)
    mock.stubs(:type).returns(Trinidad::Tomcat::Lifecycle::BEFORE_STOP_EVENT)
    lambda {
      listener.lifecycleEvent(mock)
    }.should_not raise_error
  end

  it "tries to initialize the context when the event is BEFORE_START_EVENT" do
    mock = mock('event')
    mock.stubs(:type).returns(Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT)
    mock.stubs(:lifecycle).returns(Trinidad::Tomcat::StandardContext.new)
    
    listener = Trinidad::Lifecycle::WebApp::Default.new(nil)
    lambda {
      listener.lifecycleEvent(mock)
    }.should raise_error
  end

  it "doesn't load a default web xml when the deployment descriptor is not provided" do
    listener = rails_web_app_listener({})
    context = web_app_context(listener.web_app)
    listener.send(:configure_deployment_descriptor, context).should be nil
  end

  it "loads a default web xml when the deployment descriptor is provided" do
    FakeFS do
      create_rails_web_xml

      listener = rails_web_app_listener({
        :web_app_dir => Dir.pwd,
        :default_web_xml => 'config/web.xml'
      })
      context = web_app_context(listener.web_app)
      
      expected_xml = File.join(Dir.pwd, 'config/web.xml')

      listener.send(:configure_deployment_descriptor, context).should == expected_xml

      context.find_lifecycle_listeners.
        map {|l| l.class.name }.should include('Java::OrgApacheCatalinaStartup::ContextConfig')

      context_configs = context.find_lifecycle_listeners.select do |listener|
        listener.class.name == 'Java::OrgApacheCatalinaStartup::ContextConfig'
      end
      context_configs.size.should == 1
      context_configs.first.default_web_xml.should == expected_xml
    end
  end

  it "adds the rack servlet and the mapping for /*" do
    listener = rails_web_app_listener({})
    listener.send :configure_rack_servlet, context

    servlet = context.find_child('RackServlet')
    servlet.should_not be nil
    servlet.servlet_class.should == 'org.jruby.rack.RackServlet'

    context.find_servlet_mapping('/*').should == 'RackServlet'
  end

  it "configures the rack context listener from the web app" do
    listener = rackup_web_app_listener({})
    context = web_app_context(listener.web_app)
    listener.send :configure_rack_listener, context

    context.find_application_listeners.to_a.
      should include('org.jruby.rack.RackServletContextListener')
  end

  it "configures the rails context listener from the web app" do
    listener = rails_web_app_listener({})
    context = web_app_context(listener.web_app)
    listener.send :configure_rack_listener, context

    context.find_application_listeners.to_a.
      should include('org.jruby.rack.rails.RailsServletContextListener')
  end
  
  it "adds context parameters from the web app" do
    listener = rails_web_app_listener({ :jruby_min_runtimes => 1 })
    listener.send :configure_context_params, context

    context.find_parameter('jruby.min.runtimes').should == '1'
  end

  it "ignores parameters already present in the deployment descriptor" do
    listener = rails_web_app_listener({
      :jruby_max_runtimes => 1,
      :web_app_dir => MOCK_WEB_APP_DIR,
      :default_web_xml => 'config/web.xml'
    })
    context = tomcat.add_webapp('/', Dir.pwd)
    listener.stubs(:configure_logging)
    listener.configure(context)

    context.find_parameter('jruby.max.runtimes').should be nil
    context.start
    context.find_parameter('jruby.max.runtimes').should == '4'
  end

  it "doesn't load classes into a jar when the libs directory is not present" do
    listener = rails_web_app_listener({})
    web_app = listener.web_app
    listener.send :add_application_jars, web_app.class_loader

    lambda {
      web_app.class_loader.find_class('org.ho.yaml.Yaml')
    }.should raise_error
  end

  it "loads classes into a jar when the libs directory is provided" do
    listener = rails_web_app_listener({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :libs_dir => 'lib'
    })
    web_app = listener.web_app
    listener.send :add_application_jars, web_app.class_loader

    lambda {
      web_app.class_loader.find_class('org.ho.yaml.Yaml').should_not be nil
    }.should_not raise_error
  end

  it "doesn't load java classes when the classes directory is not present" do
    listener = rails_web_app_listener({})
    web_app = listener.web_app
    listener.send :add_application_java_classes, web_app.class_loader

    lambda {
      web_app.class_loader.find_class('HelloTomcat')
    }.should raise_error
  end

  it "loads java classes when the classes directory is provided" do
    listener = rackup_web_app_listener({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :classes_dir => 'classes'
    })
    web_app = listener.web_app
    listener.send :add_application_java_classes, web_app.class_loader

    lambda {
      web_app.class_loader.find_class('HelloTomcat').should_not be nil
    }.should_not raise_error
  end

  it "creates a WebappLoader with the JRuby class loader" do
    listener = rackup_web_app_listener({})
    listener.send :configure_context_loader, context

    context.loader.should be_a(Java::OrgApacheCatalinaLoader::WebappLoader)
  end

  it "loads the default application from the current directory using the rackup file if :web_apps is not present" do
    listener = rackup_web_app_listener({
      :web_app_dir => MOCK_WEB_APP_DIR, 
      :rackup => 'config.ru'
    })
    context = web_app_context(listener.web_app)
    listener.send :configure_init_params, context

    context.find_parameter('rackup.path').should == "config.ru"
  end
  
  it "loads context.xml for application from META-INF", :integration => true do
    begin
      web_app = Trinidad::WebApp.create({}, { 
          :context_path => '/rails', 
          :web_app_dir => RAILS_WEB_APP_DIR, 
          :classes_dir => 'lib/classes', # contains META-INF/context.xml
          :environment => 'production' }
      )
      #logger = java.util.logging.Logger.getLogger('org.apache.catalina.startup.ContextConfig')
      #logger.level = java.util.logging.Level::ALL
      #console_handler  = java.util.logging.ConsoleHandler.new
      #console_handler.level = java.util.logging.Level::ALL
      #logger.addHandler(console_handler)
      
      context = tomcat.addWebapp(web_app.context_path, web_app.web_app_dir)
      context.addLifecycleListener web_app.define_lifecycle
      context.start
      
      context.getDefaultContextXml.should == File.join(RAILS_WEB_APP_DIR, 'lib/classes/META-INF/context.xml')
      context.getSessionCookieName.should == 'TRINICOOKIE'
      
      valves = context.pipeline.valves.to_a
      valves.find { |valve| valve.is_a?(Java::OrgApacheCatalinaValves::AccessLogValve) }.should_not be nil
      
      params = context.getServletContext.getInitParameterNames.to_a
      params.should include('theOldParameter')
      context.getServletContext.getInitParameter('theZenParameter').should == '42'
      
      #logger.level = java.util.logging.Level::INFO
      #logger.removeHandler(console_handler)
    end
  end
  
  it "has 2 child servlets mapped by default when context starts", :integration => true do
    listener = rackup_web_app_listener({
      :web_app_dir => MOCK_WEB_APP_DIR, 
      :rackup => 'config.ru'
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.find_children.to_a.should == []
    context.start

    context.find_children.size.should == 2
    wrapper1 = context.find_children[0]
    wrapper1.should be_a org.apache.catalina.core.StandardWrapper
    wrapper1.getServletClass.should == 'org.jruby.rack.RackServlet'
    wrapper1.name.should == 'RackServlet'
    context.findServletMapping('/*').should == 'RackServlet'

    wrapper2 = context.find_children[1]
    wrapper2.should be_a org.apache.catalina.core.StandardWrapper
    wrapper2.getServletClass.should == 'org.apache.catalina.servlets.DefaultServlet'
  end
  
  it "keeps DefaultServlet when option is true", :integration => true do
    listener = rackup_web_app_listener({
      :default_servlet => true,
      :web_app_dir => MOCK_WEB_APP_DIR, 
      :rackup => 'config.ru'
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    wrapper = default_wrapper(context)
    wrapper.name.should == 'default'
    wrapper.getServletClass.should == 'org.apache.catalina.servlets.DefaultServlet'
    context.findServletMapping('/').should == 'default'
  end

  it "re-configures DefaultServlet when default in web.xml", :integration => true do
    FileUtils.touch custom_web_xml = "#{MOCK_WEB_APP_DIR}/default-web.xml"
    begin
      create_config_file custom_web_xml, '' +
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<web-app>' +
        '  <servlet>' +
        '    <servlet-class>org.apache.catalina.servlets.CGIServlet</servlet-class>' +
        '    <servlet-name>default</servlet-name>' +
        '  </servlet>' +
        '  <servlet-mapping>' +
        '    <url-pattern>/default</url-pattern>' +
        '    <servlet-name>default</servlet-name>' +
        '  </servlet-mapping>' +
        '</web-app>'

      listener = rackup_web_app_listener({
        :web_xml => 'default-web.xml',
        :web_app_dir => MOCK_WEB_APP_DIR, 
        :rackup => 'config.ru'
      })
      context = web_app_context(listener.web_app)
      context.addLifecycleListener listener
      context.start

      wrapper = default_wrapper(context)
      wrapper.name.should == 'default'
      wrapper.getServletClass.should == 'org.apache.catalina.servlets.CGIServlet'
      context.findServletMapping('/default').should == 'default'
      
      context.find_children.find do |wrapper|
        wrapper.getServletClass == 'org.apache.catalina.servlets.DefaultServlet'
      end.should be nil
    ensure
      FileUtils.rm custom_web_xml
    end
  end
  
  class DefaultServlet < org.apache.catalina.servlets.DefaultServlet
    field_accessor :input, :output, :debug
    
    def initialize
      super
      self.output = self.input = 4224
    end
  end
  
  it "allows overriding DefaultServlet with (configured) servlet instance", :integration => true do
    listener = rackup_web_app_listener({
      :default_servlet => servlet = DefaultServlet.new,
      :web_app_dir => MOCK_WEB_APP_DIR, 
      :rackup => 'config.ru'
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    wrapper = default_wrapper(context)
    wrapper.name.should == 'default'
    wrapper.getServletClass.should_not == 'org.apache.catalina.servlets.DefaultServlet'
    wrapper.getServlet.should be servlet
    context.findServletMapping('/').should == 'default'
    servlet.input.should == 4224
    
    context.find_children.find do |wrapper|
      wrapper.getServletClass == 'org.apache.catalina.servlets.DefaultServlet'
    end.should be nil
  end
  
  it "allows overriding DefaultServlet with servlet and custom mapping", :integration => true do
    listener = rackup_web_app_listener({
      :default_servlet => { :instance => servlet = DefaultServlet.new, :mapping => [ '/static1', '/static2' ] },
      :web_app_dir => MOCK_WEB_APP_DIR, 
      :rackup => 'config.ru'
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    wrapper = default_wrapper(context)
    wrapper.name.should == 'default'
    wrapper.getServlet.should be servlet
    context.findServletMapping('/').should == 'default'
    context.findServletMapping('/static1').should == 'default'
    context.findServletMapping('/static2').should == 'default'
  end
  
  private
  
  def default_wrapper(context)
    context.find_children.size.should >= 1
    context.find_children.find do |wrapper|
      wrapper.name == 'default'
    end
  end
  
  def web_app_context(web_app)
    tomcat.addWebapp(web_app.context_path || '/', web_app.web_app_dir)
  end
  
  def rails_web_app_listener(config)
    web_app = Trinidad::RailsWebApp.new(config, nil)
    Trinidad::Lifecycle::WebApp::Default.new(web_app)
  end

  def rackup_web_app_listener(config)
    web_app = Trinidad::RackupWebApp.new(config, nil)
    Trinidad::Lifecycle::WebApp::Default.new(web_app)
  end
  
end

describe "Trinidad::Lifecycle::Default" do
  it "still works" do
    Trinidad::Lifecycle::Default.should == Trinidad::Lifecycle::WebApp::Default
  end
end
