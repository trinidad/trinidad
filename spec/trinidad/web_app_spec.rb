require File.dirname(__FILE__) + '/../spec_helper'

describe Trinidad::WebApp do
  before do
    @tomcat = Trinidad::Tomcat::Tomcat.new
    @tomcat.host.app_base = Dir.pwd
    @app_context = @tomcat.addWebapp('/', File.dirname(__FILE__) + '/../../')

    @app_config = {
      :web_app_dir => MOCK_WEB_APP_DIR,
      :context_path => '/'
    }
    @config = {
      :libs_dir => 'lib',
      :classes_dir => 'classes',
      :default_web_xml => 'config/web.xml',
      :jruby_min_runtimes => 2,
      :jruby_max_runtimes => 6,
      :web_apps => {
        :default => @app
      }
    }
    @web_app = Trinidad::RailsWebApp.new(@app_context, @config, @app_config)
  end

  it "creates a RailsWebApp if rackup option is not present" do
    app = Trinidad::WebApp.create(@app_context, @config, @app_config)
    app.should be_an_instance_of(Trinidad::RailsWebApp)
  end

  it "creates a RackupWebApp if rackup option is present" do
    rackup_app = {:rackup => 'config.ru'}
    @config.deep_merge({:web_apps => {:default => rackup_app}})
    app = Trinidad::WebApp.create(@app_context, @config, rackup_app)
    app.should be_an_instance_of(Trinidad::RackupWebApp)
  end

  it "should load custom jars" do 
    class_loader = org.jruby.util.JRubyClassLoader.new(JRuby.runtime.jruby_class_loader)
    @web_app.add_application_libs(class_loader)

    resource = class_loader.find_class('org.ho.yaml.Yaml')
    resource.should_not be_nil
  end

  it "should load custom classes" do
    class_loader = org.jruby.util.JRubyClassLoader.new(JRuby.runtime.jruby_class_loader)
    @web_app.add_application_classes(class_loader)

    resource = class_loader.find_class('HelloTomcat')
    resource.should_not be_nil
  end

  it "should start application context without errors" do
    start_context
  end

  it "should add a filter from the default web.xml" do
    start_context_with_web_xml
    @web_app.context.findFilterDefs().should have(1).filters
  end

  it "shouldn't duplicate init params" do
    start_context_with_web_xml
    lambda { @web_app.add_init_params }.should_not raise_error
  end

  it "loads init params from configuration root" do
    @web_app.add_init_params

    @web_app.context.findParameter('jruby.min.runtimes').should == '2'
    @web_app.context.findParameter('jruby.max.runtimes').should == '6'
  end

  it 'loads init params from application node' do
    @app_config[:jruby_min_runtimes] = 4
    @app_config[:jruby_max_runtimes] = 8
    @config[:web_apps][:default] = @app_config

    web_app = Trinidad::WebApp.create(@app_context, @config, @app_config)
    web_app.add_init_params

    web_app.context.findParameter('jruby.min.runtimes').should == '4'
    web_app.context.findParameter('jruby.max.runtimes').should == '8'
  end

  it "configures rack handler" do
    @web_app.configure_rack
    @web_app.context.findChild('RackServlet').should_not be_nil
  end

  it "configures rack listener" do
    @web_app.add_rack_context_listener
    @web_app.context.findApplicationListeners().should have(1).listeners
  end

  it "has rack handler already configured when web.xml includes it" do
    @web_app.load_default_web_xml
    @web_app.rack_configured?().should  be_true

    @web_app.configure_rack
    @web_app.context.findChild('RackServlet').should be_nil
  end

  it "has rack listener already configured when web.xml includes it" do
    @web_app.load_default_web_xml
    @web_app.rack_listener_configured?().should be_true

    @web_app.add_rack_context_listener
    @web_app.context.findApplicationListeners().should have(0).listeners
  end

  it "loads the provided web.xml for rails applications" do
    @config[:default_web_xml] = 'config/foo.xml'
    app = Trinidad::WebApp.create(@app_context, @config, @app_config)

    app.load_default_web_xml
    app.context.default_web_xml.should =~ /rails_web.xml$/
  end

  it "loads the provided web.xml for rack applications" do
    @config[:default_web_xml] = 'config/foo.xml'
    @app_config[:rackup] = 'config.ru'

    app = Trinidad::WebApp.create(@app_context, @config, @app_config)
    app.load_default_web_xml
    app.context.default_web_xml.should =~ /rackup_web.xml$/
  end

  it "loads application extensions from the root of the configuration" do
    @config[:extensions] = {}
    @config[:extensions][:foo] = {}
    app = Trinidad::WebApp.create(@app_context, @config, @app_config)

    @app_context.doc_base.should_not == 'foo_app_extension'
    app.configure_extensions(@tomcat)
    @app_context.doc_base.should == 'foo_app_extension'
  end  

  def start_context_with_web_xml
    @web_app.load_default_web_xml
    start_context
  end

  def start_context
    load_tomcat_libs
    lambda { @web_app.context.start }.should_not raise_error
  end

  def load_tomcat_libs
    @web_app.config[:libs_dir] = File.join(File.dirname(__FILE__), '..', '..', 'tomcat-libs')
    @web_app.add_context_loader
  end
end
