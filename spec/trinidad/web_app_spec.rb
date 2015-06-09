require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Trinidad::WebApp do

  before { Trinidad.configuration = nil }

  it "exposes configuration via [] and readers" do
    default_config = { :context_path => '/', :rackup => 'rackup.rb' }
    app = Trinidad::WebApp.create({ :context_path => '/root' }, default_config)

    app[:context_path].should == '/root'
    app[:rackup].should == 'rackup.rb'

    app.context_path.should == '/root'
    app.rackup.should == 'rackup.rb'
  end

  it "creates a RailsWebApp if rackup option is not present" do
    app = Trinidad::WebApp.create({})
    app.should be_a(Trinidad::RailsWebApp)
  end

  it "creates a RackupWebApp if rackup option is present" do
    app = Trinidad::WebApp.create({ :rackup => 'config.ru' })
    app.should be_a(Trinidad::RackupWebApp)
  end

  it "creates a RackupWebApp if no Rails code in environment.rb" do
    application_rb = "#{MOCK_WEB_APP_DIR}/config/environment.rb"
    begin
      create_config_file application_rb, "" +
        "require 'rubygems'\n" +
        "require 'sinatra'\n\n" +
        "get ('/') { 'Hello world!' }"

      app = Trinidad::WebApp.create({ :web_app_dir => MOCK_WEB_APP_DIR })
      app.should be_a(Trinidad::RackupWebApp)
    ensure
      FileUtils.rm application_rb
    end
  end

  after do
    application_rb = "#{MOCK_WEB_APP_DIR}/config/environment.rb"
    application_rb = "#{MOCK_WEB_APP_DIR}/config/application.rb"
    FileUtils.rm application_rb if File.exist?(application_rb)
    FileUtils.rm application_rb if File.exist?(application_rb)
  end

  it "creates a RackupWebApp if no Rails code in environment.rb/application.rb" do
    application_rb = "#{MOCK_WEB_APP_DIR}/config/environment.rb"
    application_rb = "#{MOCK_WEB_APP_DIR}/config/application.rb"
    begin
      create_config_file application_rb, "" +
        "require 'sinatra'\n\n" +
        "get '/' do\n" +
        "  'Hello world!'\n" +
        "end\n"
      create_config_file application_rb, "\n"

      app = Trinidad::WebApp.create({ :web_app_dir => MOCK_WEB_APP_DIR })
      app.should be_a(Trinidad::RackupWebApp)
    ensure
      #FileUtils.rm [environment_rb, application_rb]
    end
  end

  it "creates a RailsWebApp if Rails 2.3 code in environment.rb" do
    application_rb = "#{MOCK_WEB_APP_DIR}/config/environment.rb"
    begin
      create_config_file application_rb, "" +
      "# Be sure to restart your server when you modify this file\n" +
      "\n" +
      "# Specifies gem version of Rails to use when vendor/rails is not present\n" +
      "RAILS_GEM_VERSION = '2.3.14' unless defined? RAILS_GEM_VERSION\n" +
      "\n" +
      "# Bootstrap the Rails environment, frameworks, and default configuration\n" +
      "require File.join(File.dirname(__FILE__), 'boot')\n" +
      "\n" +
      "Rails::Initializer.run do |config|\n" +
      " # ... \n" +
      "end"

      app = Trinidad::WebApp.create({ :web_app_dir => MOCK_WEB_APP_DIR })
      app.should be_a(Trinidad::RailsWebApp)
    ensure
      #FileUtils.rm environment_rb
    end
  end

  it "creates a RailsWebApp if Rails 3.x code in environment.rb/application.rb" do
    application_rb = "#{MOCK_WEB_APP_DIR}/config/environment.rb"
    application_rb = "#{MOCK_WEB_APP_DIR}/config/application.rb"
    begin
      create_config_file application_rb, "\n" +
        "# Load the rails application \n" +
        "require File.expand_path('../application', __FILE__) \n" +
        " \n " +
        "# Initialize the rails application \n" +
        "Rails3x::Application.initialize! \n"
      create_config_file application_rb, "\n" +
        "require File.expand_path('../boot', __FILE__)\n" +
        "\n" +
        "require 'rails/all'\n" +
        "\n" +
        "if defined?(Bundler)\n" +
        "  # If you precompile assets before deploying to production, use this line\n" +
        "  Bundler.require(*Rails.groups(:assets => %w(development test)))\n" +
        "  # If you want your assets lazily compiled in production, use this line\n" +
        "  # Bundler.require(:default, :assets, Rails.env)\n" +
        "end\n" +
        "\n" +
        "module Rails3x\n" +
        "  class Application < Rails::Application\n" +
        "    # ... \n" +
        "  end\n" +
        "end\n"

      app = Trinidad::WebApp.create({ :web_app_dir => MOCK_WEB_APP_DIR })
      app.should be_a(Trinidad::RailsWebApp)
    ensure
      #FileUtils.rm [environment_rb, application_rb]
    end
  end

  it "detects a RailsWebApp if (minimal) Rails code in environment.rb" do
    environment_rb = "#{MOCK_WEB_APP_DIR}/config/environment.rb"
    begin
      create_config_file environment_rb, "" +
      "require 'rubygems' \n" +
      "%w(action_controller/railtie).map &method(:require) \n" +
      "\n" +
      "class MinimalApplication < Rails::Application \n" +
      "  config.secret_token = routes.append { root :to => 'send_file#deliver' }.inspect \n" +
      "  initialize! \n" +
      "end \n" +
      "\n" +
      "#  ... \n" +
      "\n"

      app = Trinidad::WebApp.create({ :web_app_dir => MOCK_WEB_APP_DIR })
      app.should be_a(Trinidad::RailsWebApp)
    ensure
      #FileUtils.rm environment_rb
    end
  end

  it "detects a RailsWebApp if (minimal) Rails code in application.rb" do
    application_rb = "#{MOCK_WEB_APP_DIR}/config/application.rb"
    begin
      create_config_file application_rb, "" <<
      "require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE']) \n" <<
      "\n" <<
      "require 'rails/all' \n" <<
      "\n" <<
      "# Require the gems listed in Gemfile, including any gems \n" <<
      "# # you've limited to :test, :development, or :production. \n" <<
      "Bundler.require(:default, Rails.env) \n" <<
      "\n" <<
      "module Sample\n" <<
      "  class Application < Rails::Application; end\n" <<
      "end\n" <<
      "\n"

      app = Trinidad::WebApp.create({ :web_app_dir => MOCK_WEB_APP_DIR })
      app.should be_a(Trinidad::RailsWebApp)
    ensure
      #FileUtils.rm application_rb
    end
  end

  it "ignores rack_servlet when a deployment descriptor already provides it" do
    create_rails_web_xml

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml'
    })
    app.rack_servlet.should be nil
  end

  it "ignores rack_servlet when a deployment descriptor provides a 'rack' named servlet" do
    create_config_file custom_web_xml = "extended-web.xml", '' +
      '<?xml version="1.0" encoding="UTF-8"?>' +
      '<web-app>' +
      '  <servlet>' +
      '    <servlet-class>org.kares.jruby.rack.ExtendedServlet</servlet-class>' +
      '    <servlet-name>rack</servlet-name>' +
      '    <async-supported>true</async-supported>' +
      '  </servlet>' +
      '  <servlet-mapping>' +
      '    <url-pattern>/*</url-pattern>' +
      '    <servlet-name>rack</servlet-name>' +
      '  </servlet-mapping>' +
      '</web-app>'

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd, :web_xml => custom_web_xml
    })
    app.rack_servlet.should be nil
  end

  it "ignores rack_servlet when RackFilter is configured" do
    create_config_file custom_web_xml = "filter1-web.xml", '' +
      '<?xml version="1.0" encoding="UTF-8"?>' +
      '<web-app>' +
      '  <filter>' +
      '    <filter-class>org.jruby.rack.RackFilter</filter-class>' +
      '    <filter-name>filter</filter-name>' +
      '  </filter>' +
      '  <filter-mapping>' +
      '    <url-pattern>/*</url-pattern>' +
      '    <filter-name>filter</filter-name>' +
      '  </filter-mapping>' +
      '</web-app>'

    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd, :web_xml => custom_web_xml
    })
    app.rack_servlet.should be nil
  end

  it "ignores rack_servlet when a deployment descriptor provides a 'rack' named filter" do
    create_config_file custom_web_xml = "filter2-web.xml", '' +
      '<?xml version="1.0" encoding="UTF-8"?>' +
      '<web-app>' +
      '  <filter>' +
      '    <filter-class>org.kares.jruby.rack.CustomRackFilter</filter-class>' +
      '    <filter-name>rack</filter-name>' +
      '  </filter>' +
      '  <filter-mapping>' +
      '    <url-pattern>/*</url-pattern>' +
      '    <filter-name>rack</filter-name>' +
      '  </filter-mapping>' +
      '</web-app>'

    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd, :web_xml => custom_web_xml
    })
    app.rack_servlet.should be nil
  end

  it "ignores rack_listener when a deployment descriptor already provides it" do
    create_rails_web_xml

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml'
    })
    app.rack_listener.should be nil
  end

  it "does not ignore rack_servlet when it's commented in a deployment descriptor" do
    create_rails_web_xml_with_rack_servlet_commented_out

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml'
    })
    app.servlet.should_not be nil
    app.servlet[:name].should == Trinidad::WebApp::RACK_SERVLET_NAME
    app.servlet[:class].should == 'org.jruby.rack.RackServlet'
  end

  it "incorrectly formatted deployment descriptor should not be used" do
    create_rails_web_xml_formatted_incorrectly

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml'
    })
    app.deployment_descriptor.should_not be nil
    app.send(:web_xml_doc).should be nil
  end

  it "uses RackServlet with /* when a deployment descriptor is not provided" do
    app = Trinidad::WebApp.create({}, {})
    app.rack_servlet.should_not be nil
    app.rack_servlet[:name].should == Trinidad::WebApp::RACK_SERVLET_NAME
    app.rack_servlet[:class].should == 'org.jruby.rack.RackServlet'
    app.rack_servlet[:mapping].should == '/*'
  end

  it "sets to load RackServlet on startup by default" do
    app = Trinidad::WebApp.create({}, {})
    app.rack_servlet[:load_on_startup].should == 2
  end

  it "adds async_supported to rack_servlet config (false by default)" do
    app = Trinidad::WebApp.create({}, {})
    app.rack_servlet[:async_supported].should == false
  end

  it "configures async_supported from trinidad's configuration" do
    app = Trinidad::WebApp.create({ :async_supported => true })
    app.rack_servlet[:async_supported].should == true
  end

  it "configured RailsServletContextListener when a deployment descriptor is not provided" do
    app = Trinidad::WebApp.create({})
    app.rack_listener.should == 'org.jruby.rack.rails.RailsServletContextListener'
  end

  it "loads the context parameters from the configuration when a deployment descriptor is not provided" do
    app = Trinidad::WebApp.create({
      :jruby_min_runtimes => 1,
      :jruby_max_runtimes => 1,
      :jruby_compat_version => '1.9',
      :public => 'foo',
      :environment => :production
    })

    params = app.init_params
    params['jruby.min.runtimes'].should == '1'
    params['jruby.max.runtimes'].should == '1'
    params['jruby.compat.version'].should == '1.9'
    params['public.root'].should == 'foo'
    params['rails.env'].should == 'production'
  end

  it "adds the rackup script as a context parameter when it's provided" do
    create_rackup_file

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd,
      :rackup => 'config/config.ru'
    })

    app.context_params['rackup.path'].should == 'config/config.ru'
  end

  it "ignores parameters from configuration when the deployment descriptor already contains them" do
    create_rackup_web_xml

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml',
      :jruby_min_runtimes => 2,
      :jruby_max_runtimes => 5
    }, nil)

    app.context_params['jruby.min.runtimes'].should be nil
    app.context_params['jruby.max.runtimes'].should be nil
  end

  it "does not ignore parameters from configuration when the deployment descriptor has them commented" do
    create_rackup_web_xml_with_jruby_runtime_parameters_commented_out

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml',
      :jruby_min_runtimes => 2,
      :jruby_max_runtimes => 5
    })
    parameters = app.context_params

    parameters['jruby.min.runtimes'].should == '2'
    parameters['jruby.max.runtimes'].should == '5'
  end

  it "expands relative web xml paths" do
    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd,
      :web_xml => 'config/some.xml'
    })
    app.web_xml.should == 'config/some.xml'
    app.deployment_descriptor.should == File.expand_path('config/some.xml', Dir.pwd)
  end

  it "accepts absolute web xml paths" do
    default_web_xml = "/home/kares/trinidad/default.web.xml"
    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd,
      :default_web_xml => default_web_xml
    })
    app.default_web_xml.should == "/home/kares/trinidad/default.web.xml"
    app.default_deployment_descriptor.should == "/home/kares/trinidad/default.web.xml"
  end

  it "doesn't load any web.xml when the deployment descriptor doesn't exist" do
    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml'
    })
    app.rack_servlet.should_not be nil
    app.rack_servlet[:class].should_not be nil
    app.rack_listener.should_not be nil
  end

  it "uses 'public' as default public root directory" do
    app = Trinidad::WebApp.create({})
    app.public_root.should == 'public'
  end

  it "accepts and uses absolute public root path" do
    app = Trinidad::WebApp.create({
        :public => '/var/www/public',
        :root_dir => '/home/trinidad/webapp/current'
    })
    app.public_root.should == '/var/www/public'
    app.public_dir.should == '/var/www/public'
  end

  it "expands '/' public root as root dir (not absolute path)" do
    app = Trinidad::WebApp.create({
        :public => '/', :root_dir => '/home/trinidad/webapp/current'
    })
    app.public_root.should == '/'
    app.public_dir.should == '/home/trinidad/webapp/current'
  end

  it "uses extensions from the global configuration" do
    default_config = { :extensions => { :hotdeploy => {} } }
    app = Trinidad::WebApp.create({}, default_config)
    app.extensions.should include(:hotdeploy)
  end

  it "overrides global extensions with application extensions" do
    default_config = { :extensions => { :hotdeploy => {} } }
    config = { :extensions => { :hotdeploy => { :delay => 30000 } } }
    app = Trinidad::WebApp.create(config, default_config)
    app.extensions[:hotdeploy].should include(:delay)
  end

  it "creates a rackup application when the rackup file is under WEB-INF directory" do
    create_rackup_file('WEB-INF')

    app = Trinidad::WebApp.create({})

    app.should be_a(Trinidad::RackupWebApp)
  end

  it "doesn't add the rackup init parameter when the rackup file is under WEB-INF directory" do
    create_rackup_file('WEB-INF')
    app = Trinidad::WebApp.create({})

    app.init_params.should_not include('rackup.path')
  end

  it "loads rackup file from a given directory" do
    create_rackup_file('rack')

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd,
      :rackup => 'rack'
    })

    app.context_params.should include('rackup.path')
    app.context_params['rackup.path'].should == 'rack/config.ru'
  end

  it "allows to configure the servlet from the configuration options" do
    app = Trinidad::WebApp.create({
      :servlet => {
        :class => 'org.jruby.trinidad.FakeServlet',
        :name => 'FakeServlet',
        :async_supported => true,
        :mapping => '/fake'
      }
    })

    app.servlet[:class].should == 'org.jruby.trinidad.FakeServlet'
    app.servlet[:name].should == 'FakeServlet'
    app.servlet[:async_supported].should == true
    app.servlet[:mapping].should == '/fake'
  end

  it "uses the application directory as working directory" do
    app = Trinidad::WebApp.create({ :root_dir => 'foo' })
    expect( app.work_dir ).to eql File.expand_path('foo/tmp')
  end

  it "adds / in front of the context path" do
    app = Trinidad::WebApp.create({ :context_path => 'bar' })
    expect( app.context_path ).to eql '/bar'
  end

  it "accepts the context path as is" do
    app = Trinidad::WebApp.create({ :context_path => '/bar', :context_name => 'huu' })
    expect( app.context_path ).to eql '/bar'
  end

  it "resolves the context path from name" do
    app = Trinidad::WebApp.create({ :context_name => 'huu' })
    expect( app.context_path ).to eql '/huu'
  end

  it "resolves context name 'default' as root path" do
    app = Trinidad::WebApp.create :context_name => 'default'
    expect( app.context_path ).to eql '/'
  end

  it "configures default context / with correct root directory" do
    app = Trinidad::WebApp.create :context_name => 'default'
    expect( app.root_dir ).to eql Dir.pwd

    app = Trinidad::WebApp.create :web_apps => { :default => { 'extensions' => {} } }
    expect( app.context_path ).to eql '/'
    expect( app.root_dir ).to eql Dir.pwd

    app = Trinidad::WebApp.create :address => 'localhost', 'web_apps' => {
      'default' => { 'extensions' => { 'foo' => { :sample => 42 } } }
    }
    expect( app.context_path ).to eql '/'
    expect( app.root_dir ).to eql Dir.pwd
  end

  it "converts context name to_s" do
    app = Trinidad::WebApp.create({ :context_name => :home, :context_path => :'/home' })
    app.context_name.should ==  'home'
    app.context_path.should == '/home'
  end

  it "a missing context name stays nil" do
    app = Trinidad::WebApp.create({ :context_path => '/home' })
    app.context_name.should be nil
  end

  it "missing context path assumes root" do
    app = Trinidad::WebApp.create({})
    app.context_path.should == '/'
  end

  it "uses development as default environment when the option is missing" do
    app = Trinidad::WebApp.create({})
    app.environment.should == 'development'
  end

  it "converts environment to a string" do
    app = Trinidad::WebApp.create(:environment => :staging)
    app.environment.should == 'staging'
  end

  it 'resolves environment from web.xml' do
    FileUtils.touch env_web_xml = "#{MOCK_WEB_APP_DIR}/config/env.web.xml"
    begin
      create_config_file env_web_xml, '' <<
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<web-app>' +
        '  <context-param>' +
        '    <param-name>rack.env</param-name>' +
        '    <param-value>production2</param-value>' +
        '  </context-param>' +
        '</web-app>'
      app = Trinidad::WebApp.create({
        :context_path => '/',
        :web_app_dir => MOCK_WEB_APP_DIR,
        :environment => 'testing',
        :default_web_xml => 'config/env.web.xml'
      })

      app.environment.should == 'production2'
    ensure
      FileUtils.rm env_web_xml
    end
  end

  it "includes the ruby version as a parameter to load the jruby compatibility version" do
    app = Trinidad::WebApp.create({})
    app.init_params.should include('jruby.compat.version')
    app.init_params['jruby.compat.version'].should == RUBY_VERSION
  end

  it "uses tmp/restart.txt as a monitor file for context reloading" do
    app = Trinidad::WebApp.create({}, { :web_app_dir => MOCK_WEB_APP_DIR })
    app.monitor.should == File.expand_path('tmp/restart.txt', MOCK_WEB_APP_DIR)

    app = Trinidad::WebApp.create({ :root_dir => MOCK_WEB_APP_DIR }, nil)
    app.monitor.should == File.expand_path('tmp/restart.txt', MOCK_WEB_APP_DIR)
  end

  it "accepts a monitor file (relalive to work_dir) as configuration parameter" do
    app = Trinidad::WebApp.create({
      :root_dir => MOCK_WEB_APP_DIR,
      :monitor => 'foo.txt'
    })
    app.monitor.should == File.expand_path('tmp/foo.txt', MOCK_WEB_APP_DIR)

    app = Trinidad::WebApp.create({
      :root_dir => MOCK_WEB_APP_DIR,
      :work_dir => MOCK_WEB_APP_DIR,
      :monitor => 'foo.txt'
    })
    app.monitor.should == File.expand_path('foo.txt', MOCK_WEB_APP_DIR)
  end

  it "is threadsafe when min and max runtimes are 1" do
    app = Trinidad::WebApp.create({}, {
      :root_dir => MOCK_WEB_APP_DIR,
      :jruby_min_runtimes => 1, :jruby_max_runtimes => 1
    })

    app.threadsafe?.should be true
  end

  it "is not threadsafe when min and max runtimes are not 1" do
    app = Trinidad::WebApp.create(
      :root_dir => MOCK_WEB_APP_DIR,
      :jruby_min_runtimes => 1, :jruby_max_runtimes => 2
    )

    app.threadsafe?.should be false
  end

  it "is not threadsafe when min and max runtimes are not 1 (in default config)" do
    app = Trinidad::WebApp.create({}, {
      :root_dir => MOCK_WEB_APP_DIR,
      :jruby_min_runtimes => 1, :jruby_max_runtimes => 2
    })

    app.threadsafe?.should be false
  end

  it "can specify threadsafe as an option" do
    app = Trinidad::WebApp.create({}, {
      :root_dir => MOCK_WEB_APP_DIR, :threadsafe => true
    })

    app.threadsafe?.should be true

    app = Trinidad::RailsWebApp.new({
      :root_dir => MOCK_WEB_APP_DIR, :threadsafe => true
    })

    app.threadsafe?.should be true

    app = Trinidad::RailsWebApp.new({}, {
      :root_dir => MOCK_WEB_APP_DIR, :threadsafe => false
    })

    app.threadsafe?.should be false

    app = Trinidad::RackWebApp.new({
      :root_dir => MOCK_WEB_APP_DIR, :threadsafe => false
    })

    app.threadsafe?.should be false

    app = Trinidad::RackWebApp.new({}, {
      :root_dir => MOCK_WEB_APP_DIR, :threadsafe => true
    })

    app.threadsafe?.should be true

    app = Trinidad::RackWebApp.new({ :threadsafe => true }, {
      :root_dir => MOCK_WEB_APP_DIR
    })

    app.threadsafe?.should be true
  end

  it "sets jruby runtime pool to 1 when it detects the threadsafe flag in the specified environment" do
    create_rails_environment('environments/staging.rb')
    FileUtils.rm_r 'WEB-INF' if File.exists?('WEB-INF')

    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd,
      :environment => 'staging',
      }, {
      #:jruby_min_runtimes => 1, :jruby_max_runtimes => 2
    })

    app.jruby_min_runtimes.should == 1
    app.jruby_max_runtimes.should == 1 # overrides default config
    app.threadsafe?.should be true
  end

  it "sets jruby runtime pool to 1 when it detects the threadsafe Rails 4.0" do
    create_config_file "config/environments/production.rb", <<-EOF
Rails40::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both thread web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like nginx, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Disable Rails's static asset server (Apache or nginx will already do this).
  config.serve_static_assets = false

  # Compress JavaScripts and CSS.
  config.assets.js_compressor  = :uglifier
  # config.assets.css_compressor = :sass

  # Whether to fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Generate digests for assets URLs.
  config.assets.digest = true

  # Version of your assets, change this if you want to expire all your assets.
  config.assets.version = '1.0'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Set to :debug to see everything in the log.
  config.log_level = :info

  # Prepend all log lines with the following tags.
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups.
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)
end
EOF
    FileUtils.rm_r 'WEB-INF' if File.exists?('WEB-INF')

    app = Trinidad::WebApp.create({
        :root_dir => Dir.pwd, :environment => 'production',
      }, {
        #:jruby_min_runtimes => 2, :jruby_max_runtimes => 4
      }
    )

    app.jruby_min_runtimes.should == 1
    app.jruby_max_runtimes.should == 1 # overrides default config
    app.threadsafe?.should be true
  end

  it "detects threadsafe Rails 4.x" do
    create_config_file "config/environments/production.rb", <<-EOF
MyAPI::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes= true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both thread web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load  =  true # ok

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # ...
end
EOF
    FileUtils.rm_r 'WEB-INF' if File.exists?('WEB-INF')

    app = Trinidad::WebApp.create({
        :root_dir => Dir.pwd, :environment => 'production',
      }, {})

    expect( app.threadsafe? ).to be true
    app.jruby_min_runtimes.should == 1
    app.jruby_max_runtimes.should == 1 # overrides default config

    app = Trinidad::WebApp.create({ :root_dir => Dir.pwd, :environment => 'production' })
    expect( app.threadsafe? ).to be true
  end

  @@__eager_load_false_rails4x = <<-EOF
MyAPI::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes= true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both thread web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = false
  # config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # ...
end
EOF

  it "detects non-threadsafe Rails 4.x" do
    create_config_file "config/environments/production.rb", @@__eager_load_false_rails4x
    # FileUtils.rm_r 'WEB-INF' if File.exists?('WEB-INF')

    app = Trinidad::WebApp.create(:root_dir => Dir.pwd, :environment => 'production')
    expect( app.threadsafe? ).to be false

    app.jruby_min_runtimes.should == 5
    app.jruby_max_runtimes.should == 5
  end

  it "defaults min_runtimes to 1 in non-threadsafe mode (Rails 4.x)" do
    create_config_file "config/environments/production.rb", @@__eager_load_false_rails4x

    app = Trinidad::WebApp.create(:root_dir => Dir.pwd, :environment => 'development')
    expect( app.threadsafe? ).to be false

    app.jruby_min_runtimes.should == 1
    app.jruby_max_runtimes.should == 5
  end

  it "detects app as threadsafe in development when production set for thread-safe (Rails 4.x)" do
    create_config_file "config/environment.rb", <<-EOF
# Load the Rails application.
#require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails40::Application.initialize!
EOF
    create_config_file "config/environments/production.rb", <<-EOF
Rails40::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both thread web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like nginx, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Disable Rails's static asset server (Apache or nginx will already do this).
  config.serve_static_assets = false

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Generate digests for assets URLs.
  config.assets.digest = true

  # Version of your assets, change this if you want to expire all your assets.
  config.assets.version = '1.0'

  # Set to :debug to see everything in the log.
  config.log_level = :info

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new
end
EOF
    create_config_file "config/environments/development.rb", <<-EOF
Rails40::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true
end
EOF
    FileUtils.rm_r 'WEB-INF' if File.exists?('WEB-INF')

    app = Trinidad::WebApp.create(:root_dir => Dir.pwd, :environment => 'development')

    expect( app.threadsafe? ).to be true

    app = Trinidad::WebApp.create(:root_dir => Dir.pwd, :environment => 'test')
    expect( app.threadsafe? ).to be true
  end

  it "sets jruby runtime pool to 1 when it detects the threadsafe flag in the rails environment.rb" do
    create_rails_environment

    app = Trinidad::WebApp.create(:web_app_dir => Dir.pwd)

    app.threadsafe?.should be true
  end

  it "does not change jruby runtime pool settings (even for a threadsafe) app" do
    create_rails_environment

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd,
      :jruby_min_runtimes => 1,
      :jruby_max_runtimes => 2
    })

    app.jruby_min_runtimes.should == 1
    app.jruby_max_runtimes.should == 2
    app.threadsafe?.should be false
  end

  it "does not change jruby runtime pool settings for a threadsafe app (default config)" do
    create_rails_environment

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd
    },
    { :jruby_min_runtimes => 3, :jruby_max_runtimes => 6 }
    )

    app.jruby_min_runtimes.should == 3
    app.jruby_max_runtimes.should == 6
    app.threadsafe?.should be false
  end

  it "does not set threadsafe when the option is not enabled" do
    create_rails_environment_non_threadsafe

    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd
    })

    app.threadsafe?.should be false
  end

  it "changes to threadsafe mode when option provided" do
    create_rails_environment_non_threadsafe

    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd, :threadsafe => true
    })

    app.jruby_min_runtimes.should == 1
    app.jruby_max_runtimes.should == 1
    app.threadsafe?.should be true
  end

  it "detects a rackup web app even if :rackup present in main config" do
    create_rackup_file 'main'
    FileUtils.rm_r 'config' if File.exists?('config')

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd
    }, {
      :rackup => 'main/config.ru'
    })

    app.should be_a(Trinidad::RackupWebApp)
    app.context_params['rackup.path'].should == 'main/config.ru'
  end

  it "sets app.root param for a rack application" do
    app = Trinidad::WebApp.create({
      :root_dir => MOCK_WEB_APP_DIR,
      :environment => :production
    })

    app.context_params['app.root'].should == MOCK_WEB_APP_DIR
  end

  it "sets (and expands) rails.root param for a rails application" do
    app = Trinidad::WebApp.create({
      :root_dir => File.join(File.dirname(__FILE__), '../web_app_rails'),
      :environment => :staging
    })

    app.context_params['rails.root'].should == RAILS_WEB_APP_DIR
  end

  it "sets layout class param for a rack application" do
    app = Trinidad::WebApp.create({
      :root_dir => MOCK_WEB_APP_DIR + '../../spec/web_app_mock'
    })

    if JRuby::Rack::VERSION == '1.1.10'
      app.context_params['jruby.rack.layout_class'].should == 'JRuby::Rack::RailsFilesystemLayout'
      app.context_params['gem.path'].should_not be nil # due a jruby-rack bug
      app.context_params['rails.root'].should_not be nil # no support for app.root
    else
      app.context_params['jruby.rack.layout_class'].should == 'JRuby::Rack::FileSystemLayout'
    end
  end

  it "sets layout class param for a rails application" do
    app = Trinidad::WebApp.create({
      :root_dir => RAILS_WEB_APP_DIR  + '/../../spec/web_app_rails',
      :environment => 'production'
    })

    if JRuby::Rack::VERSION == '1.1.10'
      app.context_params['jruby.rack.layout_class'].should == 'JRuby::Rack::RailsFilesystemLayout'
      app.context_params['gem.path'].should_not be nil
      app.context_params['rails.root'].should == RAILS_WEB_APP_DIR # should be expanded
    else
      app.context_params['jruby.rack.layout_class'].should == 'JRuby::Rack::FileSystemLayout'
    end
  end

  it "does look for jruby context param values from system properties" do
    app = Trinidad::WebApp.create({})
    app.context_params['jruby.compat.version'].should == RUBY_VERSION
    app.context_params['jruby.runtime.acquire.timeout'].should_not be nil
    begin
      java.lang.System.setProperty('jruby.compat.version', '1_9')
      java.lang.System.setProperty('jruby.runtime.acquire.timeout', '4.2')

      app.reset!
      app.context_params['jruby.compat.version'].should == '1_9'
      app.context_params['jruby.runtime.acquire.timeout'].should == '4.2'

      app2 = Trinidad::WebApp.create({ :jruby_runtime_acquire_timeout => 9.5 })
      app2.context_params['jruby.runtime.acquire.timeout'].should == '9.5'

      app3 = Trinidad::WebApp.create({}, { :jruby_runtime_acquire_timeout => 1.25 })
      app3.context_params['jruby.runtime.acquire.timeout'].should == '1.25'
    ensure
      java.lang.System.clearProperty('jruby.compat.version')
      java.lang.System.clearProperty('jruby.runtime.acquire.timeout')
    end
  end

  it "accepts and expands java_classes and java_lib" do
    app = Trinidad::WebApp.create({
      :root_dir => '/home/kares',
      :java_classes => 'java/classes',
      :java_lib => 'java/lib'
    })
    app.java_classes.should == 'java/classes'
    app.java_lib.should == 'java/lib'

    app.java_classes_dir.should == '/home/kares/java/classes'
    app.java_lib_dir.should == '/home/kares/java/lib'
  end

  it "accepts absolute paths for java_classes and java_lib" do
    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd,
      :java_classes => '/home/trinidad/shared/classes',
      :java_lib => '/home/trinidad/shared/jars'
    })
    app.java_classes_dir.should == '/home/trinidad/shared/classes'
    app.java_lib_dir.should =='/home/trinidad/shared/jars'
  end

  it "expands java_classes as 'classes' relative to java_lib" do
    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd,
      :java_lib => '/home/trinidad/shared'
    })
    app.java_classes_dir.should == '/home/trinidad/shared/classes'
  end

  it "uses sensible defaults for java_classes and java_lib" do
    app = Trinidad::WebApp.create({ :root_dir => Dir.pwd })
    app.java_lib.should =='lib/java'
    app.java_classes.should == 'lib/java/classes'
  end

  it "handles (old) :classes_dir and :libs_dir syntax" do
    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd,
      :classes_dir => 'klasses',
      :libs_dir => 'thelib'
    })
    app.java_classes.should == 'klasses'
    app.java_lib.should == 'thelib'
  end

  it "sets public root" do
    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd, :public => 'assets'
    })

    app.public.should == 'assets'
    app.public_root.should == 'assets'
  end

  it "accepts public configuration" do
    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd, :public => {
        :root => 'assets',
        :cache => false
      }
    })

    app.public_root.should == 'assets'
    app.caching_allowed?.should == false
  end

  it "accepts public configuration cache parameters" do
    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd, :public => {
        :cached => true,
        :cache_ttl => 60 * 1000,
        :cache_max_size => 100 * 1000,
        :cache_object_max_size => 1000
      }
    })

    app.public_root.should == 'public'
    app.caching_allowed?.should == true
    app.cache_ttl.should == 60000
    app.cache_max_size.should == 100000
    app.cache_object_max_size.should == 1000
  end

  it "turns off caching in development (if not specified)" do
    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd, :environment => 'development'
    })

    app.caching_allowed?.should == false
  end

  it "turns on caching in non-development" do
    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd, :environment => 'production'
    })

    app.caching_allowed?.should == true
  end

  it "parses (context-param) xml values correctly" do
    FileUtils.touch custom_web_xml = "#{MOCK_WEB_APP_DIR}/config/custom.web.xml"
    begin
      create_config_file custom_web_xml, '' +
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<web-app>' +
        '  <context-param>' +
        '    <param-name>jruby.initial.runtimes</param-name>' +
        '    <param-value>1</param-value>' +
        '  </context-param>' +
        '  <filter>' +
        '    <filter-name>RackFilter</filter-name>' +
        '    <filter-class>org.jruby.rack.RackFilter</filter-class>' +
        '  </filter>' +
        '  <listener>' +
        '    <listener-class>org.jruby.rack.rails.RailsServletContextListener</listener-class>' +
        '  </listener>' +
        '' +
        '  <context-param>' +
        '    <param-name>jruby.rack.logging.name</param-name>' +
        '    <param-value>/root</param-value>' +
        '  </context-param>' +
        '' +
        '  <servlet>' +
        '    <load-on-startup>2</load-on-startup>' +
        '    <servlet-name>custom-servlet</servlet-name>' +
        '    <servlet-class>org.kares.jruby.CustomServlet</servlet-class>' +
        '    <async-supported>true</async-supported>' +
        '  </servlet>' +
        '  <servlet-mapping>' +
        '    <url-pattern>/_custom</url-pattern>' +
        '    <url-pattern>*.custom</url-pattern>' +
        '    <servlet-name>custom-servlet</servlet-name>' +
        '  </servlet-mapping>' +
        '</web-app>'
      web_app = Trinidad::WebApp.create({}, {
        :context_path => '/',
        :web_app_dir => MOCK_WEB_APP_DIR,
        :default_web_xml => 'config/custom.web.xml'
      })

      web_app.web_xml_context_param('jruby.rack.logging').should be nil
      web_app.web_xml_context_param('jruby.rack.logging.name').should == '/root'

      web_app.web_xml_filter?('org.jruby.rack.RackFilter').should be true
      web_app.web_xml_filter?('org.jruby.rack.Rack').should be false
      web_app.web_xml_filter?(nil, 'Rack').should be false
      web_app.web_xml_filter?(nil, 'RackFilter').should be true

      web_app.web_xml_listener?('org.jruby.rack.rails').should be false
      web_app.web_xml_listener?('org.jruby.rack.rails.RailsServletContextListener').should be true

      web_app.web_xml_servlet?('org.jruby.rack.RackServlet').should be false
      web_app.web_xml_servlet?(nil, 'RackServlet').should be false
      web_app.web_xml_servlet?('org.kares.jruby.CustomServlet').should be true
      web_app.web_xml_servlet?(nil, 'custom-servlet').should be true
      # NOTE: class not found but if name given assumes there's a "replacement" servlet :
      web_app.web_xml_servlet?('org.kares.missing.ServletClass', 'custom-servlet').should be true
    ensure
      FileUtils.rm custom_web_xml
    end
  end

  it "configures a custom default servlet (by default)" do
    create_rails_web_xml

    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml'
    })
    app.default_servlet.should be_a Hash
    app.default_servlet[:class].should == 'rb.trinidad.servlets.DefaultServlet'
  end

  it "'keeps' default servlet when configured so" do
    create_rails_web_xml

    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml',
      :default_servlet => true
    })
    app.default_servlet.should be true # true - keep as is
  end

  it "'removes' default servlet when a deployment descriptor provides a default named servlet" do
    create_config_file custom_web_xml = "extended-web.xml", '' +
      '<?xml version="1.0" encoding="UTF-8"?>' +
      '<web-app>' +
      '  <servlet>' +
      '    <servlet-class>org.kares.Servlet42</servlet-class>' +
      '    <servlet-name>default</servlet-name>' +
      '    <async-supported>false</async-supported>' +
      '  </servlet>' +
      '  <servlet-mapping>' +
      '    <url-pattern>/</url-pattern>' +
      '    <servlet-name>default</servlet-name>' +
      '  </servlet-mapping>' +
      '</web-app>'

    app = Trinidad::WebApp.create({
      :web_app_dir => Dir.pwd, :web_xml => custom_web_xml
    })
    app.default_servlet.should be false # false - remove default
  end

  it "returns default servlet setup when configured" do
    create_rails_web_xml

    app = Trinidad::WebApp.create({
      :default_servlet => {
        :class => 'org.kares.DefaultServlet',
        :mapping => [ '/', '/assets' ]
      },
      :web_app_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml'
    })
    app.default_servlet.should be_a Hash
    app.default_servlet.should == {
      :class => 'org.kares.DefaultServlet',
      :mapping => [ '/', '/assets' ]
    }
  end

  it "allows aliases to be specified" do
    app = Trinidad::WebApp.create({
      :root_dir => Dir.pwd,
      :aliases => "/assets1=/home/public,/assets2=/var/www/public"
    })
    app.aliases.should == '/assets1=/home/public,/assets2=/var/www/public'
  end

  it "converts and expands aliases specified as a Hash" do
    app = Trinidad::WebApp.create({
      :root_dir => '.',
      :aliases => {
        :assets1 => '/home/public',
        :assets2 => 'app/public-ext',
        '/assets3' => '/var/www/public'
      }
    })
    app.aliases.should == "/assets1=/home/public,/assets2=#{Dir.pwd}/app/public-ext,/assets3=/var/www/public"
  end

  describe "WarWebApp" do

    it "is a war application if the context path ends with .war" do
      app = Trinidad::WebApp.create :context_path => './foo.war'
      app.should be_a(Trinidad::WarWebApp)
      expect( app.war? ).to be true

      app = Trinidad::WebApp.create :context_path => 'foo.war'
      app.should be_a(Trinidad::WarWebApp)
    end

    it "is a war application if the context path ends with .war" do
      app = Trinidad::WebApp.create :context_path => 'foo.war'
      app.should be_a(Trinidad::WarWebApp)
      app.war?.should be true
    end

    it "is a war application if root dir ends with .war" do
      app = Trinidad::WebApp.create :context_path => '/foo', :root_dir => './foo-0.1.war'
      app.should be_a(Trinidad::WarWebApp)
      expect( app.war? ).to be true
    end

    #it "removes the war extension from the context path if it's a war application" do
    #  app = Trinidad::WebApp.create :context_path => 'foo.war'
    #  app.context_path.should == '/foo'
    #end

    it "by default keep working directory nil" do
      app = new_web_app :context_path => '/foo', :root_dir => './foo.war'
      expect( app.work_dir ).to be nil
    end

    it "uses the war file to monitorize an application packed as a war" do
      app = new_web_app :root_dir => './foo.war'
      expect( app.monitor ).to eql File.expand_path('foo.war')
    end

    it "is configured to get unpacked by default" do # @see ContextConfig#fixDocBase
      server = Trinidad::Server.new :context_path => 'foo.war'
      app_holder = server.send(:deploy_web_apps).first

      expect( app_holder.context.getUnpackWAR ).to be true
      expect( server.tomcat.host.isUnpackWARs ).to be true

      expect( app_holder.web_app.doc_base[-4..-1] ).to eql '.war' # context.doc_base

      appBase = server.tomcat.host.app_base
      canonicalAppBase = java.io.File.new(appBase)
      if canonicalAppBase.isAbsolute()
        canonicalAppBase = canonicalAppBase.getCanonicalFile()
      else
        baseDir = server.tomcat.engine.getBaseDir()
        canonicalAppBase = java.io.File.new(baseDir, appBase).getCanonicalFile()
      end

      docBase = app_holder.web_app.doc_base # context.getDocBase()

      file = java.io.File.new(docBase)
      if ! file.isAbsolute()
        docBase = java.io.File.new(canonicalAppBase, docBase).getPath()
      else
        docBase = file.getCanonicalPath()
      end

      expect( docBase.to_java.startsWith(canonicalAppBase.getPath()) ).to be true
    end

    private

    def new_web_app(config); Trinidad::WarWebApp.new(config); end

  end

  let(:tomcat) { org.apache.catalina.startup.Tomcat.new }

  private

  def custom_context(web_app)
    context = CustomContext.new
    context.setName(web_app.context_path)
    context.setPath(web_app.context_path)
    context.setDocBase(web_app.context_dir)
    context.addLifecycleListener(Trinidad::Tomcat::Tomcat::DefaultWebXmlListener.new)
    context.addLifecycleListener(ctx_cfg = Trinidad::Tomcat::ContextConfig.new)
    ctx_cfg.setDefaultWebXml(tomcat.noDefaultWebXmlPath)
    tomcat.getHost().addChild(context)
    context
  end

  class CustomContext < Java::OrgApacheCatalinaCore::StandardContext

    def addChild(container)
      raise java.lang.IllegalArgumentException.new('add_child')
      super
    end

  end

end
