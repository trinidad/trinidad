require File.expand_path('../spec_helper', File.dirname(__FILE__))
require 'fileutils'

describe Trinidad::Server do
  include FakeApp

  JSystem = java.lang.System
  JContext = javax.naming.Context

  before { Trinidad.configure }
  after  { Trinidad.configuration = nil }

  after do
    keystore = Trinidad::Server::DEFAULT_KEYSTORE_FILE
    keystore = File.join('../../', keystore)
    keystore = File.expand_path(keystore, File.dirname(__FILE__))
    if File.exist?(keystore)
      if File.file?(keystore)
        File.delete(keystore)
        if Dir.entries( File.dirname(keystore) ) == [ '.', '..' ]
          Dir.rmdir File.dirname(keystore)
        end
      else
        FileUtils.rm_rf keystore
      end
    end
  end

  APP_STUBS_DIR = File.expand_path('../stubs', File.dirname(__FILE__))

  before do
    FileUtils.mkdir(APP_STUBS_DIR) unless File.exists?(APP_STUBS_DIR)
  end
  after { FileUtils.rm_r APP_STUBS_DIR }

  # less deploting app logging noise during spex :

  @@server_log = Trinidad::Server.logger
  @@server_logger_level = nil
  before(:all) do
    @@server_logger_level = @@server_log.logger.level
    @@server_log.logger.level = java.util.logging.Level::WARNING
  end
  after(:all) { @@server_log.logger.level = @@server_logger_level }


  it "always uses symbols as configuration keys" do
    Trinidad.configure { |config| config.port = 4000 }
    server = configured_server
    server.config[:port].should == 4000
  end

  it "enables catalina naming" do
    expect( configured_server.tomcat ).to_not be nil
    JSystem.get_property(JContext.URL_PKG_PREFIXES).should  include("org.apache.naming")
    JSystem.get_property(JContext.INITIAL_CONTEXT_FACTORY).should == "org.apache.naming.java.javaURLContextFactory"
    JSystem.get_property("catalina.useNaming").should == "true"
  end

  it "disables SSL when config :ssl param is nil" do
    server = configured_server
    server.ssl_enabled?.should be false
  end

  it "enables SSL when config :ssl present" do
    server = configured_server({ :ssl => { :port => 8443 }, :web_app_dir => MOCK_WEB_APP_DIR })
    server.ssl_enabled?.should be true
  end

  it "generates a 'default' SSL keystore (if does not exist already)" do
    keystore = Trinidad::Server::DEFAULT_KEYSTORE_FILE
    expect( File.exist?(keystore) ).to be false

    server = configured_server({
      :ssl => { :port => 8443 },
      :web_app_dir => MOCK_WEB_APP_DIR
    })
    server.send :initialize_tomcat

    expect( File.exist?(keystore) ).to be true
    expect( File.file?(keystore) ).to be true

    server = configured_server({
      :ssl => { :port => 8443 },
      :web_app_dir => MOCK_WEB_APP_DIR
    })
    server.send :initialize_tomcat

    expect( File.file?(keystore) ).to be true
  end

  it "enables AJP when config param is a number" do
    server = configured_server( :ajp => { :port => 8009 } )
    server.ajp_enabled?.should be_true
  end

  it "configures AJP only (if :http not set)" do
    server = configured_server( :address => '127.0.0.1', :ajp => { :port => 8009 } )

    connector = server.tomcat.connector
    connector.get_property("address").to_s.should == '/127.0.0.1'

    connectors = server.tomcat.service.find_connectors
    connectors.should have(1).connector
    connectors[0].protocol.should == 'AJP/1.3'

    expect( server.tomcat.connector ).to be connectors[0]
  end

  it "configures HTTP as well as AJP" do
    server = configured_server( :address => 'localhost', :http => true, :ajp => { :port => 8009 } )

    connector = server.tomcat.connector
    connector.protocol.should == 'HTTP/1.1'

    connectors = server.tomcat.service.find_connectors
    connectors.should have(2).connector

    # connectors[1].get_property("address").to_s.should == '/localhost'
  end

  it "configures SSL only (if :http not set)" do
    server = configured_server( :https => { :port => 3443, :address => '' } )

    connectors = server.tomcat.service.find_connectors
    connectors.should have(1).connector
    expect( connectors[0].protocol ).to eql 'HTTP/1.1'
    expect( connectors[0].secure ).to be true

    expect( server.tomcat.connector ).to be connectors[0]
  end

  it "inherits :address for SSL connector" do
    server = configured_server( :address => '10.10.10.10', :https => { :port => 3443 } )

    connectors = server.tomcat.service.find_connectors
    connectors[0].get_property("address").to_s.should == '/10.10.10.10'
  end

  it "inherits :port for SSL connector (unless :http configured)" do
    begin; FileUtils.touch 'dummy.ks'
      server = configured_server( :port => 3001, :https => { :keystore => 'dummy.ks' } )
    ensure; FileUtils.rm 'dummy.ks'; end

    connectors = server.tomcat.service.find_connectors
    expect( connectors[0].port ).to eql 3001
    expect( connectors.size ).to eql 1

    server = configured_server( :port => 3001, :http => true, :https => { :port => 4001 } )

    connectors = server.tomcat.service.find_connectors
    expect( connectors[0].port ).to eql 3001
    expect( connectors[1].port ).to eql 4001
  end

  it "sets default https port 3443" do
    Trinidad.configure { |config| config.https = true }
    server = configured_server

    connectors = server.tomcat.service.find_connectors
    connectors.should have(1).connector
    expect( connectors[0].port ).to eql 3443
  end

  it "sets default https port 3443 when http used and global port specified" do
    server = configured_server( :port => 3003, :http => true, :https => true )

    connectors = server.tomcat.service.find_connectors
    connectors.should have(2).connector
    expect( connectors[0].port ).to eql 3003
    expect( connectors[1].port ).to eql 3443
  end

  it "includes a connector with https scheme when :ssl is enabled" do
    Trinidad.configure do |config|
      config.ssl = { :port => 8443 }
    end
    server = configured_server

    connectors = server.tomcat.service.find_connectors
    connectors.should have(1).connector
    connectors[0].scheme.should == 'https'
  end

  it "includes an AJP protocol connector with when :ajp is enabled" do
    Trinidad.configure do |config|
      config.ajp = {:port => 8009}
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
    Trinidad.configure {|config| config.web_app_dir = MOCK_WEB_APP_DIR}
    server = deployed_server

    default_context_should_be_loaded(server.tomcat.host.find_children)
  end

  it "uses the default (blocking) connector when http is not configured" do
    server = Trinidad::Server.new
    server.http_configured?.should be false

    server.tomcat.connector.protocol_handler_class_name.should == 'org.apache.coyote.http11.Http11Protocol'
  end

  it "uses the NIO connector when the http configuration sets nio to true" do
    server = configured_server :web_app_dir => MOCK_WEB_APP_DIR, :http => { :nio => true }
    server.http_configured?.should be true

    server.tomcat.connector.protocol_handler_class_name.should == 'org.apache.coyote.http11.Http11NioProtocol'
    server.tomcat.connector.protocol.should == 'org.apache.coyote.http11.Http11NioProtocol'
  end

  it "configures NioConnector with http option values" do
    server = configured_server({
      :root_dir => MOCK_WEB_APP_DIR,
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

  it "keeps TC's server address as localhost when no :address given" do
    server = configured_server({ :root_dir => MOCK_WEB_APP_DIR })
    tomcat = server.send :initialize_tomcat
    expect( tomcat.server.address ).to eql 'localhost'
  end

  it "sets TC's server address based on :address option" do
    server = configured_server :root_dir => MOCK_WEB_APP_DIR, :address => '127.0.0.1'
    tomcat = server.send :initialize_tomcat
    expect( tomcat.server.address ).to eql '127.0.0.1'
  end

  it "adds the default lifecycle listener to each webapp" do
    Trinidad.configuration.web_app_dir = MOCK_WEB_APP_DIR
    server = deployed_server

    default_context(server).find_lifecycle_listeners.map { |l| l.class.name }.
      should include('Trinidad::Lifecycle::WebApp::Default')
  end

  it "loads application extensions from the root of the configuration" do
    Trinidad.configure do |config|
      config.web_app_dir = MOCK_WEB_APP_DIR
      config.extensions = { :muu => {} }
    end
    server = deployed_server

    expect( default_context(server).doc_base ).to eql 'muu'
  end

  it "doesn't create a default keystore when the option SSLCertificateFile is " <<
     "present in the ssl configuration options" do
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

  it "supports setting address to '*'" do
    server = configured_server(:address => '*')
    server.tomcat.host.name.should == '0.0.0.0'
    server.tomcat.server.address.should == '0.0.0.0'
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
      FileUtils.mkdir 'app_base'
      FileUtils.cp_r MOCK_WEB_APP_DIR, 'app_base/test'

      server = deployed_server :app_base => 'app_base'

      listeners = find_listeners(server, Trinidad::Lifecycle::Default)
      listeners.first.webapp.should be_a(Trinidad::RackupWebApp)
    ensure
      FileUtils.rm_rf 'app_base'
    end
  end

  it "adds the APR lifecycle listener to the server if the option is available" do
    server = configured_server :http => { :apr => true }

    server.tomcat.server.find_lifecycle_listeners.
      select { |listener| listener.instance_of?(Trinidad::Tomcat::AprLifecycleListener) }.
      should have(1).listener
  end

  it "adds the default lifecycle listener" do
    server = deployed_server :root_dir => MOCK_WEB_APP_DIR

    listeners = find_listeners(server, Trinidad::Lifecycle::Default)
    listeners.should have(1).listener
  end

  it "adds the war lifecycle listener when the application is a .war file" do
    begin
      Dir.mkdir('apps_base')

      server = configured_server :apps_base => 'apps_base'
      server.send(:create_web_app, { :context_path => '/foo.war', :root_dir => './webapps/foo.war' })

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
    } })

    server.tomcat.engine.find_children.should have(2).hosts
  end

  it "adds aliases to the hosts when we provide an array of host names" do
    server = configured_server( :hosts => {
      'foo' => ['localhost', 'local'],
      'lol' => ['lololhost', 'lol']
    })

    hosts = server.tomcat.engine.find_children
    expect( hosts.map { |host| host.aliases }.flatten ).to eql ['lol', 'local']
  end

  it "doesn't add any alias when we only provide the host name" do
    server = configured_server( :hosts => {
      'foo' => 'localhost', 'lol' => 'lolhost'
    })

    hosts = server.tomcat.engine.find_children
    expect( hosts.map { |host| host.aliases }.flatten ).to eql []
  end

  it "sets default host app base to current working directory" do
    server = configured_server
    expect( server.tomcat.host.app_base ).to eql Dir.pwd
  end

  it "allows detailed host configuration" do
    server = configured_server( :hosts => {
      :default => {
        :name => 'localhost',
        :app_base => '/home/kares/apps',
        :unpackWARs => true,
        :deploy_on_startup => false,
      },
      :serverhost => {
        :aliases => [ :'server.host' ],
        :create_dirs => false
      }
    } )

    server.tomcat.engine.find_children.should have(2).hosts

    default_host = server.tomcat.host
    expect( default_host.name ).to eql 'localhost'
    expect( default_host.app_base ).to eql '/home/kares/apps'
    expect( default_host.unpackWARs ).to be true
    expect( default_host.deploy_on_startup ).to be false

    server_host = server.tomcat.engine.find_children.find { |host| host != default_host }
    expect( server_host.name ).to eql 'serverhost'
    expect( server_host.aliases[0] ).to eql 'server.host'
    expect( server_host.create_dirs ).to be false
  end

  it "assigns apps to default host with configured address" do
    FileUtils.mkdir_p APP_STUBS_DIR + '/local/app1'
    FileUtils.mkdir_p APP_STUBS_DIR + '/local/app2'

    Dir.chdir(APP_STUBS_DIR) do
      server = deployed_server({
        :address => '0.0.0.0',
        :web_apps => {
          :app1 => {
            :root_dir => 'local/app1'
          },
          :app2 => {
            :root_dir => 'local/app2', :host => '0.0.0.0'
          }
        }
      })

      default_host = server.tomcat.host
      host_listener = default_host.find_lifecycle_listeners.
        find { |listener| listener.instance_of?(Trinidad::Lifecycle::Host) }

      app_dirs = host_listener.app_holders.map { |holder| holder.web_app.root_dir }
      expected = [ 'local/app1', 'local/app2' ].map { |dir| File.expand_path(dir) }
      expect( app_dirs ).to eql expected

      other_host = server.tomcat.engine.find_children.find { |host| host != default_host }
      expect( other_host ).to be nil
    end
  end

  it "assigns apps to host(s) correctly" do
    FileUtils.mkdir_p APP_STUBS_DIR + '/local/app11'
    FileUtils.mkdir_p APP_STUBS_DIR + '/local/app12'
    FileUtils.mkdir_p APP_STUBS_DIR + '/all/app'
    absolute_dir = java.lang.System.get_property('java.io.tmpdir')
    FileUtils.mkdir_p File.join(absolute_dir, '/domains/127.0.0.1')
    FileUtils.mkdir_p File.join(absolute_dir, '/domains/0.0.0.0')

    Dir.chdir(APP_STUBS_DIR) do
      server = deployed_server({
        :hosts => {
          "#{absolute_dir}/domains/127.0.0.1" => [ 'localhost', '127.0.0.1' ],
          :serverhost => {
            :app_base => "#{absolute_dir}/domains/0.0.0.0", :aliases => [ '0.0.0.0' ]
          }
        },
        :web_apps => {
          :app11 => {
            :root_dir => 'local/app11', :host => 'localhost'
          },
          :app12 => {
            :root_dir => 'local/app12'
          },
          :app => {
            :root_dir => 'all/app', :hosts => [ '0.0.0.0' ]
          },
        }
      })

      default_host = server.tomcat.host
      host_listener = default_host.find_lifecycle_listeners.
        find { |listener| listener.instance_of?(Trinidad::Lifecycle::Host) }

      app_dirs = host_listener.app_holders.map { |holder| holder.web_app.root_dir }
      expected = [ 'local/app11', 'local/app12' ].map { |dir| File.expand_path(dir) }
      expect( app_dirs ).to eql expected

      server_host = server.tomcat.engine.find_children.find { |host| host != default_host }
      host_listener = server_host.find_lifecycle_listeners.
        find { |listener| listener.instance_of?(Trinidad::Lifecycle::Host) }

      app_dirs = host_listener.app_holders.map { |holder| holder.web_app.root_dir }
      expected = [ 'all/app' ].map { |dir| File.expand_path(dir) }
      expect( app_dirs ).to eql expected
    end
  end

  it "selects apps for given host" do
    FileUtils.mkdir_p APP_STUBS_DIR + '/foo/mock1'
    FileUtils.mkdir_p APP_STUBS_DIR + '/foo/mock2'
    FileUtils.mkdir_p APP_STUBS_DIR + '/bar/main'
    FileUtils.mkdir_p APP_STUBS_DIR + '/baz/main'
    absolute_dir = java.lang.System.get_property('java.io.tmpdir')
    FileUtils.mkdir_p app_dir = File.join(absolute_dir, '/domains/local/app')
    FileUtils.mkdir_p File.join(absolute_dir, '/domains/server')

    Dir.chdir(APP_STUBS_DIR) do
      server = deployed_server({
        :hosts => {
          "#{absolute_dir}/domains/local" => [ 'localhost', 'local.host' ],
          :serverhost => {
            :app_base => "#{absolute_dir}/domains/server", :aliases => [ 'server.host' ]
          }
        },
        :web_apps => {
          :foo1 => {
            :root_dir => 'foo/mock1', :hosts => ['localhost', 'local.host']
          },
          :foo2 => {
            :root_dir => 'foo/mock2', :host => 'localhost'
          },
          :bar => {
            :root_dir => 'bar/main', :hosts => [ 'server.host' ]
          },
          :baz => {
            :root_dir => 'baz/main', :host_name => 'serverhost'
          },
          :app => { :root_dir => 'app' }
        }
      })

      default_host = server.tomcat.host
      host_listener = default_host.find_lifecycle_listeners.
        find { |listener| listener.instance_of?(Trinidad::Lifecycle::Host) }

      app_dirs = host_listener.app_holders.map { |holder| holder.web_app.root_dir }
      expected = [ 'foo/mock1', 'foo/mock2' ].map { |dir| File.expand_path(dir) } << app_dir
      expect( app_dirs ).to eql expected

      server_host = server.tomcat.engine.find_children.find { |host| host != default_host }
      host_listener = server_host.find_lifecycle_listeners.
        find { |listener| listener.instance_of?(Trinidad::Lifecycle::Host) }

      app_dirs = host_listener.app_holders.map { |holder| holder.web_app.root_dir }
      expected = [ 'bar/main', 'baz/main' ].map { |dir| File.expand_path(dir) }
      expect( app_dirs ).to eql expected
    end
  end

  after do
    temp_domains = java.lang.System.get_property('java.io.tmpdir') + '/domains'
    FileUtils.rm_rf( temp_domains ) if File.exist?(temp_domains)
  end

  it "creates several hosts when they are set in the web_apps configuration" do
    server = configured_server({
      :web_apps => {
        :mock1 => {
          :web_app_dir => 'foo/mock1', :hosts => 'localhost'
        },
        :mock2 => {
          :root_dir => 'bar/mock2', :host => 'lololhost'
        }
      }
    })

    children = server.tomcat.engine.find_children
    children.should have(2).hosts
  end

  it "doesn't create a host if it already exists" do
    server = configured_server({
      :web_apps => {
        :mock1 => {
          :root_dir => 'foo/mock1', :host => 'localhost'
        },
        :mock2 => {
          :web_app_dir => 'foo/mock2', :hosts => [ 'localhost' ]
        }
      }
    })

    children = server.tomcat.engine.find_children
    children.should have(1).hosts
  end

  it "sets up host base dir based on (configured) web apps" do
    FileUtils.mkdir_p APP_STUBS_DIR + '/foo/app'
    FileUtils.mkdir_p baz_dir = APP_STUBS_DIR + '/foo/baz'
    FileUtils.mkdir_p bar1_dir = APP_STUBS_DIR + '/var/www/bar1'
    FileUtils.mkdir_p APP_STUBS_DIR + '/var/www/bar2'

    server = configured_server({
      :web_apps => {
        :foo => {
          :root_dir => 'spec/stubs/foo/app', :host => 'localhost'
        },
        :baz => {
          :root_dir => baz_dir, :hosts => [ 'baz.host' ]
        },
        :bar1 => {
          :root_dir => bar1_dir, :host => 'bar.host'
        },
        :bar2 => {
          :root_dir => 'spec/stubs/var/www/bar2', :hosts => 'bar.host'
        }
      }
    })

    default_host = server.tomcat.host # localhost app_base is pwd by default
    expect( default_host.app_base ).to eql File.expand_path('.')

    baz_host = server.tomcat.engine.find_child('baz.host')
    expect( baz_host.app_base ).to eql File.expand_path(APP_STUBS_DIR + '/foo/baz')

    bar_host = server.tomcat.engine.find_child('bar.host')
    expect( bar_host.app_base ).to eql File.expand_path(APP_STUBS_DIR + '/var/www')
  end

  it "creates (configured) web apps" do
    FileUtils.mkdir_p foo_dir = APP_STUBS_DIR + '/foo'
    FileUtils.mkdir_p bar1_dir = APP_STUBS_DIR + '/bar1'
    FileUtils.mkdir_p bar2_dir = APP_STUBS_DIR + '/bar2'
    FileUtils.touch war_dir = "#{APP_STUBS_DIR}/my-app#0.1.war"

    server = configured_server({
      :web_apps => {
        :default => { :root_dir => MOCK_WEB_APP_DIR },
        :foo_app => { :root_dir => 'spec/stubs/foo', :context_name => 'foo' },
        :bar1 => { :root_dir => bar1_dir, :context_path => '/bar-app' },
        :bar2 => { :root_dir => bar2_dir },
        :war => { :root_dir => war_dir, :context_path => '/myapp' },
      }
    })
    web_apps = server.send(:create_web_apps)

    expect( web_apps.size ).to eql 5

    app_holder = web_apps.shift
    expect( app_holder.web_app.root_dir ).to eql MOCK_WEB_APP_DIR
    expect( app_holder.web_app.context_name ).to eql 'default'
    expect( app_holder.web_app.context_path ).to eql '/'
    expect( app_holder.context.name ).to eql 'default'
    expect( app_holder.context.path ).to eql '/'

    app_holder = web_apps.shift
    expect( app_holder.web_app.root_dir ).to eql foo_dir
    expect( app_holder.web_app.context_name ).to eql 'foo'
    expect( app_holder.web_app.context_path ).to eql '/foo'
    expect( app_holder.context.name ).to eql 'foo'
    expect( app_holder.context.path ).to eql '/foo'

    app_holder = web_apps.shift
    expect( app_holder.web_app.root_dir ).to eql bar1_dir
    expect( app_holder.web_app.context_name ).to eql 'bar1'
    expect( app_holder.web_app.context_path ).to eql '/bar-app'
    expect( app_holder.context.name ).to eql 'bar1'
    expect( app_holder.context.path ).to eql '/bar-app'

    app_holder = web_apps.shift
    expect( app_holder.web_app.root_dir ).to eql bar2_dir
    expect( app_holder.web_app.context_name ).to eql 'bar2'
    expect( app_holder.web_app.context_path ).to eql '/bar2'
    expect( app_holder.context.name ).to eql 'bar2'
    expect( app_holder.context.path ).to eql '/bar2'

    app_holder = web_apps.shift
    expect( app_holder.web_app.root_dir ).to eql war_dir
    expect( app_holder.web_app.context_name ).to eql 'war'
    expect( app_holder.web_app.context_path ).to eql '/myapp'
    expect( app_holder.context.name ).to eql 'war'
    expect( app_holder.context.path ).to eql '/myapp'
  end

  it "creates default web app" do
    web_apps = nil
    Dir.chdir(MOCK_WEB_APP_DIR) do
      server = configured_server
      web_apps = server.send(:create_web_apps)
    end

    expect( web_apps.size ).to eql 1

    app_holder = web_apps.shift
    expect( app_holder.web_app.root_dir ).to eql MOCK_WEB_APP_DIR
    expect( app_holder.web_app.context_name ).to eql 'default'
    expect( app_holder.web_app.context_path ).to eql '/'
  end

  it "resolves apps relative to host base (for relative/missing root)" do
    FileUtils.mkdir_p APP_STUBS_DIR + '/local/foo'
    FileUtils.mkdir_p APP_STUBS_DIR + '/server/foo'
    FileUtils.mkdir_p APP_STUBS_DIR + '/server/bar'

    Dir.chdir(APP_STUBS_DIR + '/local') do
      server = configured_server({
        :hosts => {
          :server => {
            :app_base => APP_STUBS_DIR + '/server',
            :name => 'serverhost',
            :aliases => [ 'server.host' ]
          }
        },
        :web_apps => {
          :foo => {
            :context_path => '/foo', :host_name => 'localhost'
          },
          :server_foo => {
            :root_dir => '../server/foo', :host => 'server.host'
          },
          :bar => { :host_name => 'serverhost' }
        }
      })

      web_apps = server.send(:create_web_apps)

      expect( web_apps.size ).to eql 3

      app_holder = web_apps.shift
      expect( app_holder.web_app.root_dir ).to eql APP_STUBS_DIR + '/local/foo'
      expect( app_holder.web_app.context_path ).to eql '/foo'

      app_holder = web_apps.shift
      expect( app_holder.web_app.root_dir ).to eql APP_STUBS_DIR + '/server/foo'
      expect( app_holder.web_app.context_path ).to eql '/server_foo'

      app_holder = web_apps.shift
      expect( app_holder.web_app.root_dir ).to eql APP_STUBS_DIR + '/server/bar'
      expect( app_holder.web_app.context_path ).to eql '/bar'
    end
  end

  it "only auto-deploys apps once if configured (for app_base)" do
    FileUtils.mkdir_p APP_STUBS_DIR + '/local/foo1'
    FileUtils.mkdir_p APP_STUBS_DIR + '/local/foo2'
    FileUtils.mkdir_p APP_STUBS_DIR + '/local/foo3'

    Dir.chdir(APP_STUBS_DIR + '/local') do
      server = configured_server({
        :app_base => APP_STUBS_DIR + '/local',
        :web_apps => {
          :foo1 => { :context_path => '/foo1' },
          :foo3 => { :root_dir => 'foo3' }
        }
      })

      web_apps = server.send(:create_web_apps)

      expect( web_apps.size ).to eql 3

      app_holder = web_apps.shift
      expect( app_holder.web_app.root_dir ).to eql APP_STUBS_DIR + '/local/foo1'
      expect( app_holder.web_app.context_path ).to eql '/foo1'

      app_holder = web_apps.shift
      expect( app_holder.web_app.root_dir ).to eql APP_STUBS_DIR + '/local/foo3'
      expect( app_holder.web_app.context_path ).to eql '/foo3'

      app_holder = web_apps.shift
      expect( app_holder.web_app.root_dir ).to eql APP_STUBS_DIR + '/local/foo2'
      expect( app_holder.web_app.context_path ).to eql '/foo2'
    end
  end

  it "only deploys expanded .war directory (and ignores hidden folders)" do
    FileUtils.mkdir_p APP_STUBS_DIR + '/local/foo'
    FileUtils.touch APP_STUBS_DIR + '/local/foo.war'
    FileUtils.mkdir_p APP_STUBS_DIR + '/local/.foo' # hidden dir
    FileUtils.mkdir_p APP_STUBS_DIR + '/local/work' # and host work_dir

    Dir.chdir(APP_STUBS_DIR + '/local') do
      server = configured_server :app_base => Dir.pwd,
                                 :host => { :work_dir => 'work' } # default host
      web_apps = server.send(:create_web_apps)

      expect( web_apps.size ).to eql 1

      app_holder = web_apps.shift
      expect( app_holder.web_app.root_dir ).to eql APP_STUBS_DIR + '/local/foo'
      expect( app_holder.web_app.context_path ).to eql '/foo'
    end
  end

  it "only deploys configured .war file (with custom context path)" do
    FileUtils.mkdir_p APP_STUBS_DIR + '/local/foo'
    FileUtils.touch APP_STUBS_DIR + '/local/foo_production-0.1.war'

    Dir.chdir(APP_STUBS_DIR + '/local') do
      server = configured_server :app_base => Dir.pwd,
        :web_apps => { :foo => { :context_path => '/foo', :root_dir => 'foo_production-0.1.war' } }
      web_apps = server.send(:create_web_apps)

      expect( web_apps.size ).to eql 1

      app_holder = web_apps.shift
      expect( app_holder.web_app.root_dir ).to eql APP_STUBS_DIR + '/local/foo_production-0.1.war'
      expect( app_holder.web_app.context_path ).to eql '/foo'
    end
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

  def default_context(server)
    server.tomcat.host.find_children.first
  end

  def find_listeners(server, listener_class = nil)
    default_context(server).find_lifecycle_listeners.select do |listener|
      listener_class ? listener.instance_of?(listener_class) : true
    end
  end

  def default_context_should_be_loaded(children)
    children.should have(1).web_apps
    children[0].doc_base.should == MOCK_WEB_APP_DIR
    children[0].path.should == '/'
    children[0]
  end

end
