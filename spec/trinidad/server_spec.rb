require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fakeapp'
include FileUtils
include FakeApp

JSystem = java.lang.System
JContext = javax.naming.Context

describe Trinidad::Server do
  before { Trinidad.configure }

  after do
    rm_rf File.expand_path('../../ssl', File.dirname(__FILE__))
  end

  it "always uses symbols as configuration keys" do
    Trinidad.configure {|c| c.port = 4000 }
    server = Trinidad::Server.new
    server.config[:port].should == 4000
  end

  it "enables catalina naming" do
    Trinidad::Server.new
    JSystem.get_property(JContext.URL_PKG_PREFIXES).should  include("org.apache.naming")
    JSystem.get_property(JContext.INITIAL_CONTEXT_FACTORY).should == "org.apache.naming.java.javaURLContextFactory"
    JSystem.get_property("catalina.useNaming").should == "true"
  end

  it "disables ssl when config param is nil" do
    server = Trinidad::Server.new
    server.ssl_enabled?.should be_false
  end

  it "disables ajp when config param is nil" do
    server = Trinidad::Server.new
    server.ajp_enabled?.should be_false
  end

  it "enables ssl when config param is a number" do
    begin
      server = Trinidad::Server.new({:ssl => {:port => 8443},
        :web_app_dir => MOCK_WEB_APP_DIR})

      server.ssl_enabled?.should be_true
      File.exist?('ssl').should be_true
    ensure
      rm_rf(File.expand_path('../../ssl', File.dirname(__FILE__)))
    end
  end

  it "enables ajp when config param is a number" do
    server = Trinidad::Server.new({:ajp => {:port => 8009}})
    server.ajp_enabled?.should be_true
  end

  it "includes a connector with https scheme when ssl is enabled" do
    Trinidad.configure do |c|
      c.ssl = {:port => 8443}
    end
    server = Trinidad::Server.new

    connectors = server.tomcat.service.find_connectors
    connectors.should have(1).connector
    connectors[0].scheme.should == 'https'
  end

  it "includes a connector with protocol AJP when ajp is enabled" do
    Trinidad.cleanup
    Trinidad.configure do |c|
      c.ajp = {:port => 8009}
    end
    server = Trinidad::Server.new

    connectors = server.tomcat.service.find_connectors
    connectors.should have(1).connector
    connectors[0].protocol.should == 'AJP/1.3'
  end

  it "loads one application for each option present into :web_apps" do
    server = Trinidad::Server.new({
      :web_apps => {
        :mock1 => {
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

    context_loaded = server.tomcat.host.find_children
    context_loaded.should have(3).web_apps

    expected = ['/mock1', '/mock2', '']
    context_loaded.each do |context|
      expected.delete(context.path).should == context.path
    end
  end

  it "loads the default application from the current directory if :web_apps is not present" do
    Trinidad.cleanup
    Trinidad.configure {|c| c.web_app_dir = MOCK_WEB_APP_DIR}
    server = Trinidad::Server.new

    default_context_should_be_loaded(server.tomcat.host.find_children)
  end

  it "uses the default HttpConnector when http is not configured" do
    server = Trinidad::Server.new
    server.http_configured?.should be_false

    server.tomcat.connector.protocol_handler_class_name.should == 'org.apache.coyote.http11.Http11Protocol'
  end

  it "uses the NioConnector when the http configuration sets nio to true" do
    server = Trinidad::Server.new({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :http => {:nio => true}
    })
    server.http_configured?.should be_true

    server.tomcat.connector.protocol_handler_class_name.should == 'org.apache.coyote.http11.Http11NioProtocol'
    server.tomcat.connector.protocol.should == 'org.apache.coyote.http11.Http11NioProtocol'
  end

  it "configures NioConnector with http option values" do
    server = Trinidad::Server.new({
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
    server = Trinidad::Server.new({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :address => '10.0.0.1'
    })

    connector = server.tomcat.connector
    connector.get_property("address").to_s.should == '/10.0.0.1'
  end

  it "adds the default lifecycle listener to each webapp" do
    Trinidad.configuration.web_app_dir = MOCK_WEB_APP_DIR
    server = Trinidad::Server.new
    app_context = server.tomcat.host.find_child('/')

    app_context.find_lifecycle_listeners.map {|l| l.class.name }.should include('Trinidad::Lifecycle::Default')
  end

  it "loads application extensions from the root of the configuration" do
    Trinidad.configure do |c|
      c.web_app_dir = MOCK_WEB_APP_DIR
      c.extensions = { :foo => {} }
    end
    server = Trinidad::Server.new

    app_context = server.tomcat.host.find_child('/')
    app_context.doc_base.should == 'foo_app_extension'
  end

  it "doesn't create a default keystore when the option SSLCertificateFile is present in the ssl configuration options" do
    rm_rf 'ssl'

    server = Trinidad::Server.new({
      :ssl => {
        :port => 8443,
        :SSLCertificateFile => '/usr/local/ssl/server.crt'
      },
      :web_app_dir => MOCK_WEB_APP_DIR})

    File.exist?('ssl').should be_false
  end

  it "uses localhost as host name by default" do
    Trinidad::Server.new.tomcat.host.name.should == 'localhost'
  end

  it "uses the option :address to set the host name" do
    server = Trinidad::Server.new({:address => 'trinidad.host'})
    server.tomcat.host.name.should == 'trinidad.host'
    server.tomcat.server.address.should == 'trinidad.host'
  end

  it "loads several applications if the option :apps_base is present" do
    begin
      Dir.mkdir('apps_base')
      cp_r MOCK_WEB_APP_DIR, 'apps_base/test'
      cp_r MOCK_WEB_APP_DIR, 'apps_base/test1'

      server = Trinidad::Server.new({ :apps_base => 'apps_base' })
      server.tomcat.host.find_children.should have(2).web_apps
    ensure
      rm_rf 'apps_base'
    end
  end

  it "loads rack apps from the app_base directory" do
    begin
      Dir.mkdir('apps_base')
      cp_r MOCK_WEB_APP_DIR, 'apps_base/test'

      server = Trinidad::Server.new({ :apps_base => 'apps_base' })
      listeners = find_listeners(server)
      listeners.first.webapp.should be_instance_of(Trinidad::RackupWebApp)
    ensure
      rm_rf 'apps_base'
    end
  end

  it "adds the APR lifecycle listener to the server if the option is available" do
    server = Trinidad::Server.new({
      :http => {:apr => true}
    })

    server.tomcat.server.find_lifecycle_listeners.
      select {|listener| listener.instance_of?(Trinidad::Tomcat::AprLifecycleListener)}.
      should have(1).listener
  end

  it "adds the default lifecycle listener when the application is not packed with warbler" do
    server = Trinidad::Server.new({
      :web_app_dir => MOCK_WEB_APP_DIR
    })
    listeners = find_listeners(server)
    listeners.should have(1).listener
  end

  it "adds the war lifecycle listener when the application is packed with warbler" do
    begin
      Dir.mkdir('apps_base')

      server = Trinidad::Server.new({ :apps_base => 'apps_base' })
      server.create_web_app({
        :context_path => '/foo.war',
        :web_app_dir => 'foo.war'
      })
      listeners = find_listeners(server, Trinidad::Lifecycle::War)
      listeners.should have(1).listener
    ensure
      rm_rf 'apps_base'
    end
  end

  it "adds the APR lifecycle listener to the server if the option is available" do
    server = Trinidad::Server.new({
      :http => {:apr => true}
    })

    server.tomcat.server.find_lifecycle_listeners.
      select {|listener| listener.instance_of?(Trinidad::Tomcat::AprLifecycleListener)}.
      should have(1).listener
  end

  it "creates the host listener with all the applications into the server" do
    server = Trinidad::Server.new({
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
    host_listeners.first.contexts.should have(2).applications
  end

  it "autoconfigures rack when config.ru is present in the app directory" do
    FakeFS do
      create_rackup_file('rack')
      server = Trinidad::Server.new({:web_app_dir => 'rack'})

      server.tomcat.host.find_children.should have(1).application
    end
  end

  it "creates several hosts when they are set in the configuration" do
    server = Trinidad::Server.new({:hosts => {
      'foo' => 'localhost',
      'lol' => 'lolhost'
    }})

    server.tomcat.engine.find_children.should have(2).hosts
  end

  it "adds aliases to the hosts when we provide an array of host names" do
    server = Trinidad::Server.new({:hosts => {
      'foo' => ['localhost', 'local'],
      'lol' => ['lolhost', 'lol']
    }})

    hosts = server.tomcat.engine.find_children
    hosts.map {|h| h.aliases}.flatten.should == ['lol', 'local']
  end

  it "doesn't add any alias when we only provide the host name" do
    server = Trinidad::Server.new({:hosts => {
      'foo' => 'localhost',
      'lol' => 'lolhost'
    }})

    hosts = server.tomcat.engine.find_children
    hosts.map {|h| h.aliases}.flatten.should be_empty
  end

  it "creates several hosts when they are set in the web_apps configuration" do
    server = Trinidad::Server.new({
      :web_apps => {
        :mock1 => {
          :web_app_dir => 'foo/mock1',
          :hosts       => 'localhost'
        },
        :mock2 => {
          :web_app_dir => 'bar/mock2',
          :hosts       => 'lolhost'
        }
      }
    })

    server.tomcat.engine.find_children.should have(2).hosts
  end

  it "doesn't create a host if it already exists" do
    server = Trinidad::Server.new({
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
