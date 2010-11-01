require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fakeapp'

include FakeApp

describe Trinidad::WebApp do
  it "creates a RailsWebApp if rackup option is not present" do
    app = Trinidad::WebApp.create({}, {})
    app.should be_an_instance_of(Trinidad::RailsWebApp)
  end

  it "creates a RackupWebApp if rackup option is present" do
    app = Trinidad::WebApp.create({}, {:rackup => 'config.ru'})
    app.should be_an_instance_of(Trinidad::RackupWebApp)
  end

  it "ignores rack_servlet when a deployment descriptor already provides it" do
    FakeFS do
      create_rails_web_xml

      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :default_web_xml => 'config/web.xml'
      })
      app.servlet.should be_nil
    end
  end

  it "ignores rack_listener when a deployment descriptor already provides it" do
    FakeFS do
      create_rails_web_xml

      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :default_web_xml => 'config/web.xml'
      })
      app.rack_listener.should be_nil
    end
  end

  it "does not ignore rack_servlet when it's commented in a deployment descriptor" do
    FakeFS do
      create_rails_web_xml_with_rack_servlet_commented_out

      app = Trinidad::WebApp.create({}, {
        :web_app_dir => Dir.pwd,
        :default_web_xml => 'config/web.xml'
      })
      app.servlet.should_not be_nil
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
      app.send(:web_xml).should be_nil
    end
  end

  it "uses rack_servlet as the default servlet when a deployment descriptor is not provided" do
    app = Trinidad::WebApp.create({}, {})
    app.servlet.should_not be_nil
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

      parameters['jruby.min.runtimes'].should be_nil
      parameters['jruby.max.runtimes'].should be_nil
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
    app.default_deployment_descriptor.should be_nil
  end

  it "doesn't load any web.xml when the deployment descriptor doesn't exist" do
    app = Trinidad::WebApp.create({}, {
      :web_app_dir => Dir.pwd,
      :default_web_xml => 'config/web.xml'
    })
    app.rack_servlet_configured?.should be_false
    app.rack_listener_configured?.should be_false
  end

  it "uses `public` as default public root directory" do
    app = Trinidad::WebApp.create({}, {})
    app.public_root.should == 'public'
  end

  it "uses extensions from the global configuration" do
    config = { :extensions => {:hotdeploy => {}} }
    app = Trinidad::WebApp.create(config, {})
    app.extensions.should include(:hotdeploy)
  end

  it "overrides global extensions with application extensions" do
    config = { :extensions => {:hotdeploy => {}} }
    app_config = { :extensions => {:hotdeploy => {:delay => 30000}} }
    app = Trinidad::WebApp.create(config, app_config)
    app.extensions[:hotdeploy].should include(:delay)
  end

  it "creates a rackup application when the rackup file is under WEB-INF directory" do
    FakeFS do
      create_rackup_file('WEB-INF')
      app = Trinidad::WebApp.create({}, {})

      app.should be_an_instance_of(Trinidad::RackupWebApp)
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
        :name => 'FakeServlet'
      }
    })

    app.servlet[:class].should == 'org.jruby.trinidad.FakeServlet'
    app.servlet[:name].should == 'FakeServlet'
  end

  it "is a war application if the context path ends with .war" do
    app = Trinidad::WebApp.create({}, {
      :context_path => 'foo.war'
    })
    app.war?.should be_true
    app.should be_instance_of(Trinidad::WarWebApp)
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
end
