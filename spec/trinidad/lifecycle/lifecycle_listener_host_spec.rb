require File.dirname(__FILE__) + '/../../spec_helper'

describe "Trinidad::Lifecycle::Host" do
  let(:monitor) { File.expand_path('restart.txt', MOCK_WEB_APP_DIR) }
  let(:tomcat) { Trinidad::Tomcat::Tomcat.new }
  let(:context) { mock }

  let(:start_event) do
    Trinidad::Tomcat::LifecycleEvent.new(context,
      Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT, nil)
  end

  let(:periodic_event) do
    Trinidad::Tomcat::LifecycleEvent.new(context,
      Trinidad::Tomcat::Lifecycle::PERIODIC_EVENT, nil)
  end

  let(:listener) do
    Trinidad::Lifecycle::Host.new(tomcat, {
      :context => context,
      :monitor => monitor}
    )
  end

  after { FileUtils.rm monitor if File.exist?(monitor) }

  it "creates the monitor file when receives a before start event" do
    File.exist?(monitor).should be false
    listener.lifecycleEvent(start_event)
    sleep(1)
    File.exist?(monitor).should be_true
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
      listener = Trinidad::Lifecycle::Host.new(tomcat, {
        :context => context,
        :monitor => monitor}
      )

      listener.lifecycleEvent(start_event)
      sleep(1)
      File.exist?(monitor).should be true
    end
  end

  it "creates a new context that takes over the original one" do
    context.expects(:path).once.returns('/foo')
    context.expects(:parent).once.returns(tomcat.host)

    with_host_monitor do
      app = Trinidad::WebApp.create({}, {
        :web_app_dir => MOCK_WEB_APP_DIR,
        :monitor => monitor
      })

      applications = {
        :app => app,
        :context => context,
        :monitor => monitor
      }

      listener = Trinidad::Lifecycle::Host.new(tomcat, applications)

      listener.lifecycleEvent start_event
      sleep(1)

      File.new(monitor, File::CREAT|File::TRUNC)

      listener.lifecycleEvent periodic_event

      applications[:context].should be_instance_of(Trinidad::Tomcat::StandardContext)
      applications[:context].should_not == context
    end
  end

  it "creates a new JRuby class loader for the new context" do
    context.expects(:path).once.returns('/foo')
    context.expects(:parent).once.returns(tomcat.host)

    with_host_monitor do
      app = Trinidad::WebApp.create({}, {
        :web_app_dir => MOCK_WEB_APP_DIR,
        :monitor => monitor
      })

      applications = {
        :app => app,
        :context => context,
        :monitor => monitor
      }

      old_class_loader = app.class_loader

      listener = Trinidad::Lifecycle::Host.new(tomcat, applications)

      listener.lifecycleEvent start_event
      sleep(1)

      File.new(monitor, File::CREAT|File::TRUNC)

      listener.lifecycleEvent periodic_event

      app.class_loader.should_not eq old_class_loader
    end
  end
end
