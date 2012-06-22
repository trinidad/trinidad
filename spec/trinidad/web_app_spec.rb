require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fakeapp'

include FakeApp

describe Trinidad::WebApp do
  
  it "exposes configuration via [] and readers" do
    config = { :classes_dir => 'classes', :libs_dir => 'vendor' }
    app_config = { :classes_dir => 'klasses' }
    app = Trinidad::WebApp.create(config, app_config)
    
    app[:classes_dir].should == 'klasses'
    app[:libs_dir].should == 'vendor'
    
    app.classes_dir.should == 'klasses'
    app.libs_dir.should == 'vendor'
  end
  
  it "creates a RailsWebApp if rackup option is not present" do
    app = Trinidad::WebApp.create({}, {})
    app.should be_a(Trinidad::RailsWebApp)
  end

  it "creates a RackupWebApp if rackup option is present" do
    app = Trinidad::WebApp.create({}, {:rackup => 'config.ru'})
    app.should be_a(Trinidad::RackupWebApp)
  end

  it "ignores rack_servlet when a deployment descriptor already provides it" do
    FakeFS do
      create_rails_web_xml

      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :default_web_xml => 'config/web.xml'
      })
      app.servlet.should be nil
    end
  end

  it "ignores rack_listener when a deployment descriptor already provides it" do
    FakeFS do
      create_rails_web_xml

      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :default_web_xml => 'config/web.xml'
      })
      app.rack_listener.should be nil
    end
  end

  it "does not ignore rack_servlet when it's commented in a deployment descriptor" do
    FakeFS do
      create_rails_web_xml_with_rack_servlet_commented_out

      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :default_web_xml => 'config/web.xml'
      })
      app.servlet.should_not be nil
      app.servlet[:name].should == 'RackServlet'
      app.servlet[:class].should == 'org.jruby.rack.RackServlet'
    end
  end

  it "incorrectly formatted deployment descriptor should not be used" do
    FakeFS do
      create_rails_web_xml_formatted_incorrectly

      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :default_web_xml => 'config/web.xml'
      })
      app.send(:web_xml).should be nil
    end
  end

  it "uses rack_servlet as the default servlet when a deployment descriptor is not provided" do
    app = Trinidad::WebApp.create({}, {})
    app.servlet.should_not be nil
    app.servlet[:name].should == 'RackServlet'
    app.servlet[:class].should == 'org.jruby.rack.RackServlet'
  end
  
  it "uses rack_listener as the default listener when a deployment descriptor is not provided" do
    app = Trinidad::WebApp.create({}, {})
    app.rack_listener.should == 'org.jruby.rack.rails.RailsServletContextListener'
  end

  it "loads the context parameters from the configuration when a deployment descriptor is not provided" do
    app = Trinidad::WebApp.create({}, {
      :jruby_min_runtimes => 1,
      :jruby_max_runtimes => 1,
      :public => 'foo',
      :environment => :production
    })
    parameters = app.init_params
    parameters['jruby.min.runtimes'].should == '1'
    parameters['jruby.initial.runtimes'].should == '1'
    parameters['jruby.max.runtimes'].should == '1'
    parameters['public.root'].should == '/foo'
    parameters['rails.env'].should == 'production'
    parameters['rails.root'].should == '/'
  end

  it "adds the rackup script as a context parameter when it's provided" do
    FakeFS do
      create_rackup_file
      
      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :rackup => 'config/config.ru'
      })

      parameters = app.init_params
      parameters['rackup.path'].should == 'config/config.ru'
    end
  end

  it "ignores parameters from configuration when the deployment descriptor already contains them" do
    FakeFS do
      create_rackup_web_xml

      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :default_web_xml => 'config/web.xml',
        :jruby_min_runtimes => 2,
        :jruby_max_runtimes => 5
      })
      parameters = app.init_params

      parameters['jruby.min.runtimes'].should be nil
      parameters['jruby.max.runtimes'].should be nil
    end
  end

  it "does not ignore parameters from configuration when the deployment descriptor has them commented" do
    FakeFS do
      create_rackup_web_xml_with_jruby_runtime_parameters_commented_out

      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :default_web_xml => 'config/web.xml',
        :jruby_min_runtimes => 2,
        :jruby_max_runtimes => 5
      })
      parameters = app.init_params

      parameters['jruby.min.runtimes'].should == '2'
      parameters['jruby.max.runtimes'].should == '5'
    end
  end

  it "ignores the deployment descriptor when it doesn't exist" do
    app = Trinidad::WebApp.create({}, {
      :web_app_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml'
    })
    app.default_deployment_descriptor.should be nil
  end

  it "doesn't load any web.xml when the deployment descriptor doesn't exist" do
    app = Trinidad::WebApp.create({}, {
      :web_app_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml'
    })
    app.rack_servlet_configured?.should be false
    app.rack_listener_configured?.should be false
  end

  it "uses `public` as default public root directory" do
    app = Trinidad::WebApp.create({}, {})
    app.public_root.should == 'public'
  end

  it "uses extensions from the global configuration" do
    config = { :extensions => { :hotdeploy => {} } }
    app = Trinidad::WebApp.create(config, {})
    app.extensions.should include(:hotdeploy)
  end

  it "overrides global extensions with application extensions" do
    config = { :extensions => { :hotdeploy => {} } }
    app_config = { :extensions => { :hotdeploy => { :delay => 30000 } } }
    app = Trinidad::WebApp.create(config, app_config)
    app.extensions[:hotdeploy].should include(:delay)
  end

  it "creates a rackup application when the rackup file is under WEB-INF directory" do
    FakeFS do
      create_rackup_file('WEB-INF')
      
      app = Trinidad::WebApp.create({}, {})

      app.should be_a(Trinidad::RackupWebApp)
    end
  end

  it "doesn't add the rackup init parameter when the rackup file is under WEB-INF directory" do
    FakeFS do
      create_rackup_file('WEB-INF')
      app = Trinidad::WebApp.create({}, {})

      app.init_params.should_not include('rackup.path')
    end
  end

  it "loads rackup file from a given directory" do
    FakeFS do
      create_rackup_file('rack')
      
      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :rackup => 'rack'
      })
      app.init_params.should include('rackup.path')
      app.init_params['rackup.path'].should == 'rack/config.ru'
    end
  end

  it "allows to configure the servlet from the configuration options" do
    app = Trinidad::WebApp.create({}, {
      :servlet => {
        :class => 'org.jruby.trinidad.FakeServlet',
        :name => 'FakeServlet',
        :async_supported => true
      }
    })

    app.servlet[:class].should == 'org.jruby.trinidad.FakeServlet'
    app.servlet[:name].should == 'FakeServlet'
    app.servlet[:async_supported].should == true
  end

  it "is a war application if the context path ends with .war" do
    app = Trinidad::WebApp.create({}, {
      :context_path => 'foo.war'
    })
    app.should be_a(Trinidad::WarWebApp)
    app.war?.should be true
  end

  it "uses the application directory as working directory" do
    app = Trinidad::WebApp.create({}, {
      :web_app_dir => 'foo'
    })
    app.work_dir.should == 'foo'
  end

  it "removes the war extension from the context path if it's a war application" do
    app = Trinidad::WebApp.create({}, {
      :context_path => 'foo.war'
    })
    app.context_path.should == 'foo'
  end

  it "removes the war extension from the working directory if it's a war application" do
    app = Trinidad::WebApp.create({}, {
      :context_path => 'foo.war',
      :web_app_dir => 'foo.war'
    })
    app.work_dir.should == 'foo/WEB-INF'
  end

  it "uses development as default environment when the option is missing" do
    app = Trinidad::WebApp.create({}, {})
    app.environment.should == 'development'
  end

  it "includes the ruby version as a parameter to load the jruby compatibility version" do
    app = Trinidad::WebApp.create({}, {})
    app.init_params.should include('jruby.compat.version')
    app.init_params['jruby.compat.version'].should == RUBY_VERSION
  end

  it "uses tmp/restart.txt as a monitor file for context reloading" do
    app = Trinidad::WebApp.create({
      :web_app_dir => MOCK_WEB_APP_DIR
    }, {})
    app.monitor.should == File.expand_path('tmp/restart.txt', MOCK_WEB_APP_DIR)
  end

  it "accepts a monitor file as configuration parameter" do
    app = Trinidad::WebApp.create({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :monitor => 'foo.txt'
    }, {})
    app.monitor.should == File.expand_path('foo.txt', MOCK_WEB_APP_DIR)
  end

  it "uses the war file to monitorize an application packed as a war" do
    app = Trinidad::WebApp.create({}, {
      :context_path => 'foo.war',
      :web_app_dir => 'foo.war'
    })
    app.monitor.should == File.expand_path('foo.war')
  end

  it "is threadsafe when min and max runtimes are 1" do
    app = Trinidad::WebApp.create({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :jruby_min_runtimes => 1,
      :jruby_max_runtimes => 1
    }, {})

    app.threadsafe?.should be true
  end

  it "is not threadsafe when min and max runtimes are 1" do
    app = Trinidad::WebApp.create({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :jruby_min_runtimes => 1,
      :jruby_max_runtimes => 2
    }, {})

    app.threadsafe?.should be false
  end

  it "sets jruby runtime pool to 1 when it detects the threadsafe flag in the specified environment" do
    FakeFS do
      create_rails_environment('environments/staging.rb')

      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :environment => 'staging',
        :jruby_min_runtimes => 1,
        :jruby_max_runtimes => 2
      })

      app.threadsafe?.should be true
    end
  end

  it "sets jruby runtime pool to 1 when it detects the threadsafe flag in the rails environment.rb" do
    FakeFS do
      create_rails_environment

      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :jruby_min_runtimes => 1,
        :jruby_max_runtimes => 2
      })

      app.threadsafe?.should be true
    end
  end

  it "does not set threadsafe when the option is not enabled" do
    FakeFS do
      create_rails_environment_non_threadsafe

      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :jruby_min_runtimes => 1,
        :jruby_max_runtimes => 2
      })

      app.threadsafe?.should be false
    end
  end
  
  it "detects a rackup web app even if :rackup present in main config" do
    FakeFS do
      create_rackup_file 'main'
      
      app = Trinidad::WebApp.create({ 
        :rackup => 'main/config.ru'
      }, {
        :web_app_dir => Dir.pwd
      })

      app.should be_a(Trinidad::RackupWebApp)
      app.init_params['rackup.path'].should == 'main/config.ru'
    end
  end
  
end
