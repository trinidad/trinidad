require File.dirname(__FILE__) + '/../../spec_helper'

describe Trinidad::Lifecycle::Host do
  
  let(:monitor) { File.expand_path('restart.txt', MOCK_WEB_APP_DIR) }
  let(:tomcat) { Trinidad::Tomcat::Tomcat.new }
  let(:context) { mock 'context' }

  let(:start_event) do
    Trinidad::Tomcat::LifecycleEvent.new(context,
      Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT, nil)
  end

  let(:periodic_event) do
    Trinidad::Tomcat::LifecycleEvent.new(context,
      Trinidad::Tomcat::Lifecycle::PERIODIC_EVENT, nil)
  end

  let(:listener) do
    web_app = mock('web_app')
    web_app.stubs(:monitor).returns(monitor)
    app_holder = Trinidad::WebApp::Holder.new(web_app, context)
    Trinidad::Lifecycle::Host.new(tomcat, app_holder)
  end

  after { FileUtils.rm monitor if File.exist?(monitor) }

  it "creates the monitor file when receives a before start event" do
    File.exist?(monitor).should be false
    
    listener.lifecycleEvent(start_event)
    sleep(1)
    File.exist?(monitor).should be true
  end

  it "does not create the monitor if already exists" do
    FileUtils.touch monitor
    mtime = File.mtime(monitor)
    sleep(1)
    
    listener.lifecycleEvent(start_event)
    File.mtime(monitor).should == mtime
  end

  it "creates the parent directory if it doesn't exist" do
    with_host_monitor do
      listener.lifecycleEvent(start_event)
      sleep(1)
      
      File.exist?(monitor).should be true
    end
  end

  it "creates a new context that takes over the original one" do
    context = Trinidad::Tomcat::StandardContext.new
    context.setPath('/foo'); context.setParent(tomcat.host)

    Trinidad::Tomcat::StandardContext.any_instance.stubs(:start)
    
    with_host_monitor do
      web_app = Trinidad::WebApp.create({}, {
        :web_app_dir => MOCK_WEB_APP_DIR, :monitor => monitor
      })
      app_holder = Trinidad::WebApp::Holder.new(web_app, context)
      
      listener = Trinidad::Lifecycle::Host.new(tomcat, app_holder)
      listener.lifecycleEvent start_event
      
      sleep(1)
      File.new(monitor, File::CREAT|File::TRUNC)
      
      listener.lifecycleEvent periodic_event

      app_holder.context.should be_a(Trinidad::Tomcat::StandardContext)
      app_holder.context.should_not == context
    end
  end

  it "monitor mtime gets updated once context gets replaced" do
    context = Trinidad::Tomcat::StandardContext.new
    context.setPath('/foo'); context.setParent(tomcat.host)

    Trinidad::Tomcat::StandardContext.any_instance.stubs(:start)
    
    with_host_monitor do
      web_app = Trinidad::WebApp.create({}, {
        :web_app_dir => MOCK_WEB_APP_DIR, :monitor => monitor
      })
      app_holder = Trinidad::WebApp::Holder.new(web_app, context)
      
      listener = Trinidad::Lifecycle::Host.new(tomcat, app_holder)
      listener.lifecycleEvent start_event
      app_holder.monitor_mtime.should_not be nil
      monitor_mtime = app_holder.monitor_mtime
      
      sleep(1)
      FileUtils.touch(monitor)
      
      listener.lifecycleEvent periodic_event

      app_holder.monitor_mtime.should_not == monitor_mtime
      app_holder.monitor_mtime.should == File.mtime(monitor)
    end
  end
  
  it "starts up the newly created context in another thread" do
    context = Trinidad::Tomcat::StandardContext.new
    context.setPath('/foo'); context.setParent(tomcat.host)
    
    with_host_monitor do
      web_app = Trinidad::WebApp.create({}, {
        :web_app_dir => MOCK_WEB_APP_DIR, :monitor => monitor
      })
      app_holder = Trinidad::WebApp::Holder.new(web_app, context)
      
      listener = Trinidad::Lifecycle::Host.new(tomcat, app_holder)
      listener.lifecycleEvent start_event
      
      app_holder.locked?.should be false
      Trinidad::Tomcat::StandardContext.any_instance.expects(:start)
      
      sleep(1)
      FileUtils.touch(monitor)
      
      listener.lifecycleEvent periodic_event
      app_holder.locked?.should be true
      
      sleep(1) # til Thread.new kicks in
      app_holder.locked?.should be false
    end
  end
  
  it "creates a new JRuby class loader for the new context" do
    context = Trinidad::Tomcat::StandardContext.new
    context.setPath('/foo'); context.setParent(tomcat.host)

    Trinidad::Tomcat::StandardContext.any_instance.stubs(:start)
    
    with_host_monitor do
      web_app = Trinidad::WebApp.create({}, {
        :web_app_dir => MOCK_WEB_APP_DIR, :monitor => monitor
      })
      class_loader = web_app.class_loader
      app_holder = Trinidad::WebApp::Holder.new(web_app, context)

      listener = Trinidad::Lifecycle::Host.new(tomcat, app_holder)
      listener.lifecycleEvent start_event
      
      sleep(1)
      File.new(monitor, File::CREAT|File::TRUNC)
      
      listener.lifecycleEvent periodic_event

      web_app.class_loader.should_not == class_loader
    end
  end
  
end

describe Trinidad::Lifecycle::Host::Takeover do
  
  let(:new_context) { Trinidad::Tomcat::StandardContext.new }
  let(:old_context) { Trinidad::Tomcat::StandardContext.new }

  let(:start_event) do
    Trinidad::Tomcat::LifecycleEvent.new(new_context,
      Trinidad::Tomcat::Lifecycle::AFTER_START_EVENT, nil)
  end

  let(:takeover) do
    Trinidad::Lifecycle::Host::Takeover.new(old_context)
  end

  it "stops and destorys the (old) context" do
    old_context.expects(:stop).once
    old_context.expects(:destroy).once
    takeover.lifecycleEvent(start_event)
  end
  
  it "change the context's name for the original one" do
    old_context.stubs(:stop)
    old_context.stubs(:destroy)
    old_context.name = 'foo'
    takeover.lifecycleEvent(start_event)
    new_context.name.should == 'foo'
  end
  
end

