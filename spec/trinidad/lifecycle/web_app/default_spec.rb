require File.expand_path('../../../spec_helper', File.dirname(__FILE__))

describe Trinidad::Lifecycle::WebApp::Default do

  let(:tomcat) do
    tomcat = Java::RbTrinidad::Jerry.new
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
    lambda { listener.lifecycleEvent(mock) }.should_not raise_error
  end

  it "tries to initialize the context when the event is BEFORE_START_EVENT" do
    mock = mock('event')
    mock.stubs(:type).returns(Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT)
    mock.stubs(:lifecycle).returns(Trinidad::Tomcat::StandardContext.new)

    listener = Trinidad::Lifecycle::WebApp::Default.new(nil)
    lambda { listener.lifecycleEvent(mock) }.should raise_error
  end

  it "doesn't load a default web xml when the deployment descriptor is not provided" do
    listener = rails_web_app_listener({})
    context = web_app_context(listener.web_app)
    listener.send(:configure_deployment_descriptor, context).should be nil
  end

  it "sets default web xml when the deployment descriptor is provided" do
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

    context_config = find_context_config(context)
    context_config.default_web_xml.should == expected_xml
  end

  it "ignores the deployment descriptor when it doesn't exist" do
    create_rails_web_xml

    listener = rails_web_app_listener({
      :root_dir => Dir.pwd,
      :web_xml => 'config/missing-web.xml'
    })
    context = web_app_context(listener.web_app)

    listener.send(:configure_deployment_descriptor, context).should == nil

    context_config = find_context_config(context)
    context_config.default_web_xml.should == "org/apache/catalina/startup/NO_DEFAULT_XML"
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
      :root_dir => MOCK_WEB_APP_DIR,
      :default_web_xml => 'config/web.xml'
    })
    context = tomcat.add_webapp('/', Dir.pwd)
    listener.stubs(:configure_logging)
    listener.stubs(:configure_default_servlet)
    listener.stubs(:configure_jsp_servlet)
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
      :root_dir => MOCK_WEB_APP_DIR,
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
      :root_dir => MOCK_WEB_APP_DIR,
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

  it "keeps resources base pointing to app root", :integration => true do
    listener = rackup_web_app_listener({
      :root_dir => MOCK_WEB_APP_DIR
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    context.resources.should_not be nil
    context.resources.doc_base.should == MOCK_WEB_APP_DIR
  end

  it "sets public root with the (custom) default servlet", :integration => true do
    listener = rails_web_app_listener({
      :root_dir => RAILS_WEB_APP_DIR
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    wrapper = find_wrapper(context, 'default')
    wrapper.getServlet.should be_a Java::RbTrinidadServlets::DefaultServlet
    wrapper.getServlet.getPublicRoot.should == '/public'
  end

  it "normalizes public root with the (custom) default servlet", :integration => true do
    listener = rackup_web_app_listener({
      :root_dir => MOCK_WEB_APP_DIR,
      :public => 'assets'
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    wrapper = find_wrapper(context, 'default')
    wrapper.getServlet.should be_a Java::RbTrinidadServlets::DefaultServlet
    wrapper.getServlet.getPublicRoot.should == '/assets'

    servlet = wrapper.getServlet
    servlet.public_root = nil
    servlet.public_root.should == nil
    servlet.public_root = ''
    servlet.public_root.should == nil
    servlet.public_root = '/'
    servlet.public_root.should == nil
    servlet.public_root = 'assets/'
    servlet.public_root.should == '/assets'
    servlet.public_root = '/assets/'
    servlet.public_root.should == '/assets'
  end

  it "accepts public configuration", :integration => true do
    listener = rackup_web_app_listener({
      :root_dir => MOCK_WEB_APP_DIR,
      :public => {
        :root => 'assets/',
        :cache => false
      }
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    context.caching_allowed?.should == false
    resources = context.resources.dir_context

    wrapper = find_wrapper(context, 'default')
    servlet = wrapper.servlet
    servlet.public_root.should == '/assets'
    servlet.resources.doc_base.should == MOCK_WEB_APP_DIR
    servlet.resources.cache.should be nil
  end

  it "accepts public configuration cache parameters", :integration => true do
    listener = rackup_web_app_listener({
      :root_dir => MOCK_WEB_APP_DIR,
      :public => {
        :cached => true,
        :cache_ttl => 60 * 1000,
        :cache_max_size => 100 * 1000,
        :cache_object_max_size => 1000
      }
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    context.caching_allowed?.should == true
    context.cache_ttl.should == 60000
    context.cache_max_size.should == 100000
    context.cache_object_max_size.should == 1000

    resources = context.resources.dir_context
    resources.cached?.should == true
    resources.cache_ttl.should == 60000
    resources.cache_max_size.should == 100000
    resources.cache_object_max_size.should == 1000
  end

  it "loads context.xml for application from META-INF", :integration => true do
    begin
      web_app = Trinidad::WebApp.create({}, {
          :context_path => '/rails',
          :web_app_dir => RAILS_WEB_APP_DIR,
          :java_classes => 'lib/classes', # contains META-INF/context.xml
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
      :root_dir => MOCK_WEB_APP_DIR, :rackup => 'config.ru'
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.find_children.to_a.should == []
    context.start

    context.find_children.size.should == 2

    wrapper = context.find_children[0]
    wrapper.should be_a org.apache.catalina.core.StandardWrapper
    wrapper.getServletClass.should == 'rb.trinidad.servlets.DefaultServlet'
    wrapper.name.should == 'default'
    context.findServletMapping('/').should == 'default'

    wrapper = context.find_children[1]
    wrapper.should be_a org.apache.catalina.core.StandardWrapper
    wrapper.getServletClass.should == 'org.jruby.rack.RackServlet'
    wrapper.name.should == 'rack'
    context.findServletMapping('/*').should == 'rack'

    # removes the jsp servlet by default
    context.process_tlds.should be false
  end

  it "adds the rack servlet and the mapping for /*" do
    listener = rails_web_app_listener({})
    listener.send :configure_rack_servlet, context

    servlet = context.find_child('rack')
    servlet.should_not be nil
    servlet.servlet_class.should == 'org.jruby.rack.RackServlet'

    context.find_servlet_mapping('/*').should == 'rack'
  end

  it "allows overriding the rack servlet", :integration => true do
    listener = rackup_web_app_listener({
      :rack_servlet => servlet = org.jruby.rack.RackServlet.new,
      :root_dir => MOCK_WEB_APP_DIR,
      :rackup => 'config.ru'
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    wrapper = find_wrapper(context, 'rack')
    wrapper.name.should == 'rack'
    wrapper.getServlet.should be servlet
    context.findServletMapping('/*').should == 'rack'
  end

  it "keeps DefaultServlet with a custom class (optionally adds init params)", :integration => true do
    listener = rackup_web_app_listener({
      :default_servlet => { :init_params => { :debug => 1, '_flag' => true } },
      :web_app_dir => MOCK_WEB_APP_DIR,
      :rackup => 'config.ru'
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    wrapper = find_wrapper(context, 'default')
    wrapper.name.should == 'default'
    wrapper.getServletClass.should == 'rb.trinidad.servlets.DefaultServlet'
    context.findServletMapping('/').should == 'default'
    wrapper.findInitParameter('debug').should == '1'
    wrapper.findInitParameter('_flag').should == 'true'
  end

  it "re-configures DefaultServlet when default in web.xml", :integration => true do
    create_config_file "#{MOCK_WEB_APP_DIR}/default-web.xml", '' +
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

    wrapper = find_wrapper(context, 'default')
    wrapper.name.should == 'default'
    wrapper.getServletClass.should == 'org.apache.catalina.servlets.CGIServlet'
    context.findServletMapping('/default').should == 'default'

    context.find_children.find do |wrapper|
      wrapper.getServletClass == 'org.apache.catalina.servlets.DefaultServlet'
    end.should be nil
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
      :root_dir => MOCK_WEB_APP_DIR,
      :rackup => 'config.ru'
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    wrapper = find_wrapper(context, 'default')
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
      :default_servlet => {
        :instance => servlet = DefaultServlet.new,
        :mapping => [ '/static1', '/static2' ]
      },
      :root_dir => MOCK_WEB_APP_DIR,
      :rackup => 'config.ru'
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    wrapper = find_wrapper(context, 'default')
    wrapper.name.should == 'default'
    wrapper.getServlet.should be servlet
    context.findServletMapping('/').should be nil
    context.findServletMapping('/static1').should == 'default'
    context.findServletMapping('/static2').should == 'default'
  end

  it "keeps the jsp servlet when :jsp_servlet set to true", :integration => true do
    listener = rackup_web_app_listener({
      :root_dir => MOCK_WEB_APP_DIR,
      :rackup => 'config.ru',
      :jsp_servlet => true
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    jsp_wrapper = find_wrapper(context, 'jsp')
    jsp_wrapper.should_not be nil
    jsp_wrapper.should be_a org.apache.catalina.core.StandardWrapper
    context.findServletMapping('*.jsp').should == 'jsp'
  end

  class Java::OrgApacheJasperServlet::JspServlet
    field_reader :options
  end

  it "updates the jsp servlet with given config", :integration => true do
    listener = rackup_web_app_listener({
      :root_dir => MOCK_WEB_APP_DIR,
      :rackup => 'config.ru',
      :jsp_servlet => {
        :mapping => [ '*.php', '/jspx' ],
        :init_params => { :trimSpaces => true }
      }
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    find_wrapper(context, 'jsp').should_not be nil
    context.findServletMapping('*.jsp').should == nil
    context.findServletMapping('*.php').should == 'jsp'
    context.findServletMapping('/jspx').should == 'jsp'

    wrapper = find_wrapper(context, 'jsp')
    wrapper.servlet.should be_a org.apache.jasper.servlet.JspServlet
    wrapper.servlet.options.getTrimSpaces.should == true
  end

  it "uses a custom manager for a rack web-app", :integration => true do
    listener = rackup_web_app_listener({
      :root_dir => MOCK_WEB_APP_DIR,
      :rackup => 'config.ru'
    })
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    context.start

    expect( context.manager ).to be_a org.apache.catalina.session.StandardManager
    expect( context.manager.java_class.name ).to eql 'rb.trinidad.context.DefaultManager'
  end

  it "uses a custom manager for a rails web-app", :integration => false do
    listener = rails_web_app_listener(:root_dir => RAILS_WEB_APP_DIR)
    context = web_app_context(listener.web_app)
    context.addLifecycleListener listener
    listener.send(:adjust_context, context)

    expect( context.manager ).to be_a org.apache.catalina.session.StandardManager
    expect( context.manager.java_class.name ).to eql 'rb.trinidad.context.DefaultManager'
  end

  private

  def find_context_config(context)
    context_configs = context.find_lifecycle_listeners.select do |listener|
      listener.class.name == 'Java::OrgApacheCatalinaStartup::ContextConfig'
    end
    context_configs.size.should == 1
    context_configs.first
  end

  def find_wrapper(context, name)
    context.find_children.size.should >= 1
    context.find_children.find do |wrapper|
      wrapper.name == name
    end
  end

  def web_app_context(web_app)
    tomcat.addWebapp(web_app.context_path || '/', web_app.root_dir)
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
