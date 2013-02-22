require File.expand_path('../spec_helper', File.dirname(__FILE__))
require 'fileutils'

describe Trinidad::Server do
  include FakeApp
  
  JSystem = java.lang.System
  JContext = javax.naming.Context
  
  before { Trinidad.configure }
  after  { Trinidad.configuration = nil }

  after { FileUtils.rm_rf( File.expand_path('../../ssl', File.dirname(__FILE__)) ) rescue nil }

  it "always uses symbols as configuration keys" do
    Trinidad.configure { |c| c.port = 4000 }
    server = configured_server
    server.config[:port].should == 4000
  end

  it "enables catalina naming" do
    expect( configured_server.tomcat ).to_not be nil
    JSystem.get_property(JContext.URL_PKG_PREFIXES).should  include("org.apache.naming")
    JSystem.get_property(JContext.INITIAL_CONTEXT_FACTORY).should == "org.apache.naming.java.javaURLContextFactory"
    JSystem.get_property("catalina.useNaming").should == "true"
  end

  it "disables ssl when config param is nil" do
    server = configured_server
    server.ssl_enabled?.should be false
  end

  it "disables ajp when config param is nil" do
    server = configured_server
    server.ajp_enabled?.should be false
  end

  it "enables ssl when config param is a number" do
    server = configured_server({
      :ssl => { :port => 8443 },
      :web_app_dir => MOCK_WEB_APP_DIR
    })

    server.ssl_enabled?.should be true
    #File.exist?('ssl').should be true
  end

  it "enables ajp when config param is a number" do
    server = configured_server( :ajp => { :port => 8009 } )
    server.ajp_enabled?.should be_true
  end

  it "includes a connector with https scheme when ssl is enabled" do
    Trinidad.configure do |c|
      c.ssl = {:port => 8443}
    end
    server = configured_server

    connectors = server.tomcat.service.find_connectors
    connectors.should have(1).connector
    connectors[0].scheme.should == 'https'
  end

  it "includes a connector with protocol AJP when ajp is enabled" do
    Trinidad.configure do |c|
      c.ajp = {:port => 8009}
    end
    server = configured_server

    connectors = server.tomcat.service.find_connectors
    connectors.should have(1).connector
    connectors[0].protocol.should == 'AJP/1.3'
  end

  it "loads one application for each option present into :web_apps" do
    server = configured_server({
      :web_apps => {
        :_ock1 => {
          :context_path => '/mock1',
          :web_app_dir => MOCK_WEB_APP_DIR
        },
        :mock2 => {
          :web_app_dir => MOCK_WEB_APP_DIR
        },
        :default => {
          :web_app_dir => MOCK_WEB_APP_DIR
        }
      }
    })
    server.send(:deploy_web_apps)

    context_loaded = server.tomcat.host.find_children
    context_loaded.should have(3).web_apps

    expected = [ '/mock1', '/mock2', '/' ]
    context_loaded.each do |context|
      expected.delete(context.path).should == context.path
    end
  end

  it "loads the default application from the current directory if :web_apps is not present" do
    Trinidad.configure {|c| c.web_app_dir = MOCK_WEB_APP_DIR}
    server = deployed_server

    default_context_should_be_loaded(server.tomcat.host.find_children)
  end

  it "uses the default HttpConnector when http is not configured" do
    server = Trinidad::Server.new
    server.http_configured?.should be false

    server.tomcat.connector.protocol_handler_class_name.should == 'org.apache.coyote.http11.Http11Protocol'
  end

  it "uses the NioConnector when the http configuration sets nio to true" do
    server = configured_server({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :http => {:nio => true}
    })
    server.http_configured?.should be true

    server.tomcat.connector.protocol_handler_class_name.should == 'org.apache.coyote.http11.Http11NioProtocol'
    server.tomcat.connector.protocol.should == 'org.apache.coyote.http11.Http11NioProtocol'
  end

  it "configures NioConnector with http option values" do
    server = configured_server({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :http => {
        :nio => true,
        'maxKeepAliveRequests' => 4,
        'socket.bufferPool' => 1000
      }
    })

    connector = server.tomcat.connector
    connector.get_property('maxKeepAliveRequests').should == 4
    connector.get_property('socket.bufferPool').should == '1000'
  end

  it "configures the http connector address when the address in the configuration is not localhost" do
    server = configured_server({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :address => '10.0.0.1'
    })

    connector = server.tomcat.connector
    connector.get_property("address").to_s.should == '/10.0.0.1'
  end

  it "adds the default lifecycle listener to each webapp" do
    Trinidad.configuration.web_app_dir = MOCK_WEB_APP_DIR
    server = deployed_server

    app_context = server.tomcat.host.find_child('/')

    app_context.find_lifecycle_listeners.map {|l| l.class.name }.
      should include('Trinidad::Lifecycle::WebApp::Default')
  end

  it "loads application extensions from the root of the configuration" do
    Trinidad.configure do |c|
      c.web_app_dir = MOCK_WEB_APP_DIR
      c.extensions = { :foo => {} }
    end
    server = deployed_server

    context = server.tomcat.host.find_child('/')
    context.doc_base.should == 'foo_web_app_extension'
  end

  it "doesn't create a default keystore when the option SSLCertificateFile is present in the ssl configuration options" do
    FileUtils.rm_rf 'ssl'

    server = configured_server({
      :ssl => {
        :port => 8443,
        :SSLCertificateFile => '/usr/local/ssl/server.crt'
      },
      :web_app_dir => MOCK_WEB_APP_DIR})

    File.exist?('ssl').should be false
  end

  it "uses localhost as host name by default" do
    configured_server.tomcat.host.name.should == 'localhost'
  end

  it "uses the option :address to set the host name" do
    server = configured_server :address => 'trinidad.host'
    server.tomcat.host.name.should == 'trinidad.host'
    server.tomcat.server.address.should == 'trinidad.host'
  end

  it "loads several applications if the option :apps_base is present" do
    begin
      FileUtils.mkdir 'apps_base'
      FileUtils.cp_r MOCK_WEB_APP_DIR, 'apps_base/test1'
      FileUtils.cp_r MOCK_WEB_APP_DIR, 'apps_base/test2'

      server = deployed_server :apps_base => 'apps_base'
      server.tomcat.host.find_children.should have(2).web_apps
    ensure
      FileUtils.rm_rf 'apps_base'
    end
  end

  it "loads rack apps from the apps_base directory" do
    begin
      FileUtils.mkdir 'apps_base'
      FileUtils.cp_r MOCK_WEB_APP_DIR, 'apps_base/test'

      server = deployed_server :apps_base => 'apps_base'
      listeners = find_listeners(server)
      listeners.first.webapp.should be_a(Trinidad::RackupWebApp)
    ensure
      FileUtils.rm_rf 'apps_base'
    end
  end

  it "adds the APR lifecycle listener to the server if the option is available" do
    server = configured_server( { :http => { :apr => true } } )

    server.tomcat.server.find_lifecycle_listeners.
      select {|listener| listener.instance_of?(Trinidad::Tomcat::AprLifecycleListener)}.
      should have(1).listener
  end

  it "adds the default lifecycle listener when the application is not packed with warbler" do
    server = deployed_server({
      :web_app_dir => MOCK_WEB_APP_DIR
    })
    listeners = find_listeners(server)
    listeners.should have(1).listener
  end

  it "adds the war lifecycle listener when the application is packed with warbler" do
    begin
      Dir.mkdir('apps_base')

      server = configured_server :apps_base => 'apps_base'
      server.send(:create_web_app, {
        :context_path => '/foo.war',
        :web_app_dir => 'foo.war'
      })
      listeners = find_listeners(server, Trinidad::Lifecycle::War)
      listeners.should have(1).listener
    ensure
      FileUtils.rm_rf 'apps_base'
    end
  end

  it "adds the APR lifecycle listener to the server if the option is available" do
    server = configured_server( { :http => { :apr => true } } )

    server.tomcat.server.find_lifecycle_listeners.
      select {|listener| listener.instance_of?(Trinidad::Tomcat::AprLifecycleListener)}.
      should have(1).listener
  end

  it "creates the host listener with all the applications into the server" do
    server = deployed_server({
      :web_apps => {
        :mock1 => {
          :web_app_dir => MOCK_WEB_APP_DIR
        },
        :mock2 => {
          :web_app_dir => MOCK_WEB_APP_DIR
        }
      }
    })

    host_listeners = server.tomcat.host.find_lifecycle_listeners.
      select {|listener| listener.instance_of?(Trinidad::Lifecycle::Host)}
    
    host_listeners.should have(1).listener
    listener = host_listeners[0]
    listener.app_holders.should have(2).applications
  end

  it "autoconfigures rack when config.ru is present in the app directory" do
    FakeFS do
      create_rackup_file('rack')
      server = deployed_server :web_app_dir => 'rack'

      server.tomcat.host.find_children.should have(1).application
    end
  end

  it "creates several hosts when they are set in configuration" do
    server = configured_server({ :hosts => {
      'foo' => 'localhost', :'lol' => 'lololhost'
    }})

    server.tomcat.engine.find_children.should have(2).hosts
  end

  it "adds aliases to the hosts when we provide an array of host names" do
    server = configured_server({:hosts => {
      'foo' => ['localhost', 'local'],
      'lol' => ['lololhost', 'lol']
    }})

    hosts = server.tomcat.engine.find_children
    hosts.map { |h| h.aliases }.flatten.should == ['lol', 'local']
  end

  it "doesn't add any alias when we only provide the host name" do
    server = configured_server({:hosts => {
      'foo' => 'localhost',
      'lol' => 'lolhost'
    }})

    hosts = server.tomcat.engine.find_children
    hosts.map { |h| h.aliases }.flatten.should == []
  end

  it "creates several hosts when they are set in the web_apps configuration" do
    server = configured_server({
      :web_apps => {
        :mock1 => {
          :web_app_dir => 'foo/mock1',
          :hosts       => 'localhost'
        },
        :mock2 => {
          :web_app_dir => 'bar/mock2',
          :hosts       => 'lololhost'
        }
      }
    })

    server.tomcat.engine.find_children.should have(2).hosts
  end

  it "doesn't create a host if it already exists" do
    server = configured_server({
      :web_apps => {
        :mock1 => {
          :web_app_dir => 'foo/mock1',
          :hosts       => 'localhost'
        },
        :mock2 => {
          :web_app_dir => 'foo/mock2',
          :hosts       => 'localhost'
        }
      }
    })
    server.tomcat.engine.find_children.should have(1).hosts
  end

  protected

  def configured_server(config = false)
    if config == false
      server = Trinidad::Server.new
    else
      server = Trinidad::Server.new(config)
    end
    server
  end

  def deployed_server(config = false)
    server = configured_server(config)
    server.send(:deploy_web_apps)
    server
  end

  private
  
  def find_listeners(server, listener_class = Trinidad::Lifecycle::Default)
    context = server.tomcat.host.find_children.first
    context.find_lifecycle_listeners.select do |listener|
      listener.instance_of? listener_class
    end
  end

  def default_context_should_be_loaded(children)
    children.should have(1).web_apps
    children[0].doc_base.should == MOCK_WEB_APP_DIR
    children[0].path.should == '/'
    children[0]
  end
  
end
