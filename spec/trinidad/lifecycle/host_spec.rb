require File.expand_path('../../spec_helper', File.dirname(__FILE__))

describe Trinidad::Lifecycle::Host do

  class SimpleServer < Trinidad::Server
    def initialize(tomcat)
      @tomcat = tomcat
    end
  end

  before do
    work = File.expand_path('tmp', MOCK_RACK_WEB_APP_DIR)
    FileUtils.rm_rf(work) if File.exist?(work)
  end

  let(:monitor) { File.expand_path('restart.txt', MOCK_RACK_WEB_APP_DIR) }
  let(:server) { SimpleServer.new(tomcat) }
  let(:tomcat) { org.apache.catalina.startup.Tomcat.new }
  let :context do
    context = org.apache.catalina.core.StandardContext.new
    context.setPath('/foo'); context.setParent(tomcat.host)
    context
  end

  let(:before_start_event) do
    Trinidad::Tomcat::LifecycleEvent.new(context,
      Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT, nil)
  end

  let(:periodic_event) do
    Trinidad::Tomcat::LifecycleEvent.new(context,
      Trinidad::Tomcat::Lifecycle::PERIODIC_EVENT, nil)
  end

  let(:listener) do
    web_app = double('web_app', :monitor => monitor)
    app_holder = Trinidad::WebApp::Holder.new(web_app, context)
    Trinidad::Lifecycle::Host.new(server, app_holder)
  end

  it "creates the monitor file when receives a before start event" do
    FileUtils.rm monitor if File.exist?(monitor)

    listener.lifecycleEvent(before_start_event)
    sleep(1)
    File.exist?(monitor).should be true
  end

  it "does not create the monitor if already exists" do
    FileUtils.touch monitor
    mtime = File.mtime(monitor)
    sleep(1)

    listener.lifecycleEvent(before_start_event)
    File.mtime(monitor).should == mtime
  end

  it "creates the parent directory if it doesn't exist" do
    listener.lifecycleEvent(before_start_event)
    sleep(1)

    File.exist?(monitor).should be true
  end

  it "triggers application reload if monitor changes" do
    listener.lifecycleEvent(before_start_event)
    sleep(1)
    FileUtils.touch(monitor)

    expect(listener).to receive(:reload_application!).and_return(true)
    listener.lifecycleEvent(periodic_event)
  end

  private

  def create_web_app(context_path_or_config = '/')
    config = context_path_or_config.is_a?(Hash) ? context_path_or_config : {}
    context_path = context_path_or_config.is_a?(String) && context_path_or_config
    config = {
      :context_path => context_path || '/',
      :root_dir => MOCK_RACK_WEB_APP_DIR, :public => 'assets',
      :monitor => monitor
    }.merge(config)
    Trinidad::WebApp.create({}, config)
  end

  def set_file_mtime(path, mtime)
    if mtime.is_a?(Time)
      mtime = mtime.to_f * 1000
    elsif mtime < 0 # -1 seconds
      mtime = java.lang.System.currentTimeMillis + (mtime * 1000)
    end
    file = java.io.File.new(path)
    unless file.setLastModified(mtime)
      warn "failed to set last-modified for: #{path}"
    end
  end

  describe 'RestartReload' do

    it "updates monitor mtime" do
      web_app = create_web_app
      app_holder = Trinidad::WebApp::Holder.new(web_app, context)

      listener = Trinidad::Lifecycle::Host.new(server, app_holder)
      listener.lifecycleEvent before_start_event
      app_holder.monitor_mtime.should_not be nil
      monitor_mtime = app_holder.monitor_mtime

      sleep(1)
      FileUtils.touch(monitor)

      expect(context).to receive(:reload)
      listener.lifecycleEvent periodic_event

      app_holder.monitor_mtime.should_not == monitor_mtime
      app_holder.monitor_mtime.should == File.mtime(monitor)
    end

    it 'reloads the (very same) context' do
      web_app = create_web_app
      app_holder = Trinidad::WebApp::Holder.new(web_app, context)
      set_file_mtime(monitor, -1.5)
      listener = Trinidad::Lifecycle::Host.new(server, app_holder)
      listener.lifecycleEvent before_start_event

      app_holder.locked?.should be false

      FileUtils.touch(monitor)

      expect(context).to receive(:reload)
      listener.lifecycleEvent periodic_event
      app_holder.locked?.should be false
    end

    private

    def create_web_app(config = {})
      super(config.merge(:reload_strategy => :restart))
    end

  end

  describe 'RollingReload' do

    RollingReload = Trinidad::Lifecycle::Host::RollingReload

    it "updates monitor mtime (once context gets replaced)" do
      web_app = create_web_app
      app_holder = Trinidad::WebApp::Holder.new(web_app, context)
      set_file_mtime(monitor, -1.0)
      listener = Trinidad::Lifecycle::Host.new(server, app_holder)
      listener.lifecycleEvent before_start_event
      app_holder.monitor_mtime.should_not be nil
      monitor_mtime = app_holder.monitor_mtime

      FileUtils.touch(monitor)

      listener.lifecycleEvent periodic_event

      app_holder.monitor_mtime.should_not == monitor_mtime
      app_holder.monitor_mtime.should == File.mtime(monitor)
    end

    it "creates a new context that takes over the original one" do
      web_app = create_web_app
      app_holder = Trinidad::WebApp::Holder.new(web_app, context)
      context.name = 'default'
      set_file_mtime(monitor, -2.5)
      listener = Trinidad::Lifecycle::Host.new(server, app_holder)
      listener.lifecycleEvent before_start_event

      FileUtils.rm(monitor); File.new(monitor, File::CREAT|File::TRUNC).close

      listener.lifecycleEvent periodic_event

      app_holder.context.should be_a(Trinidad::Tomcat::StandardContext)
      app_holder.context.should_not == context ###

      app_holder.context.name.should start_with context.name
    end

    it "sets new context name as context-millis (even when already set - restarted)" do
      web_app = create_web_app
      app_holder = Trinidad::WebApp::Holder.new(web_app, context)
      context.name = "default-42-#{java.lang.System.currentTimeMillis}"
      set_file_mtime(monitor, -1.5)
      listener = Trinidad::Lifecycle::Host.new(server, app_holder)
      listener.lifecycleEvent before_start_event

      FileUtils.rm(monitor); File.new(monitor, File::CREAT|File::TRUNC).close

      listener.lifecycleEvent periodic_event

      app_holder.context.name.should start_with 'default-42'
      app_holder.context.name.length.should == context.name.length
    end

    it "starts up the newly created context in another thread" do
      web_app = create_web_app
      app_holder = Trinidad::WebApp::Holder.new(web_app, context)
      set_file_mtime(monitor, -1.0)
      listener = Trinidad::Lifecycle::Host.new(server, app_holder)

      listener.lifecycleEvent before_start_event

      expect( app_holder.locked? ).to be false

      FileUtils.touch(monitor)

      expect(Thread).to receive(:new) do |&block|
        expect( app_holder.locked? ).to be true
        block.call
      end

      listener.lifecycleEvent periodic_event

      expect( app_holder.locked? ).to be false
      app_holder.context.state_name.should == 'STARTED'
    end

    it "sets (native) thread name" do
      context = org.apache.catalina.core.StandardContext.new
      roller = RollingReload.new double('server', :add_web_app => context)

      main_thread = Thread.current; reload_thread = nil
      expect(context).to receive(:start) do
        reload_thread = Thread.current
      end

      old_context = double 'old_context', :name => 'default', :path => '/',
        :parent => parent = double('parent', :remove_child => nil)
      allow(parent).to receive(:add_child).with context

      app_holder = Trinidad::WebApp::Holder.new(create_web_app, old_context)
      roller.reload!(app_holder, :wait)

      expect( reload_thread ).to_not be main_thread
      expect( thread = JRuby.reference(reload_thread) ).to_not be nil
      expect( thread.native_thread.name ).to start_with 'Trinidad'
    end

    it "logs an error when new context startup fails" do
      context = double('new context', :path => '/', :name= => nil, :remove_lifecycle_listener => nil)
      roller = RollingReload.new double('server', :add_web_app => context)

      expect(context).to receive(:add_lifecycle_listener).with { |l| l.is_a?(RollingReload::Takeover) }
      expect(context).to receive(:state_name).and_return 'NEW'

      logger = stub_logger(:debug, :info)
      expect(logger).to receive(:error) do |msg, e|
        expect( msg ).to eql 'Context with name [default] failed rolling'
        expect( e ).to be_a java.lang.Throwable
        true
      end

      expect(context).to receive(:start).and_raise RuntimeError, "what's wrong ?!"

      old_context = double 'old_context', :name => 'default', :path => '/',
        :parent => parent = double('parent', :remove_child => nil)
      expect(parent).to receive(:add_child).with context

      expect(Thread).to receive(:new).and_yield

      app_holder = Trinidad::WebApp::Holder.new(create_web_app, old_context)
      roller.reload!(app_holder)
    end

    it "removed new context and keeps old when new context fails to start" do
      context = double('new context', :path => '/', :name= => nil)
      roller = RollingReload.new double('server', :add_web_app => context)

      expect(context).to receive(:add_lifecycle_listener).
        with { |l| l.is_a?(RollingReload::Takeover) }.ordered
      expect(context).to receive(:remove_lifecycle_listener).
        with { |l| l.is_a?(RollingReload::Takeover) }.ordered

      stub_logger

      expect(context).to receive(:state_name).at_least(:once).and_return('NEW', 'FAILED')
      expect(context).to receive(:start) # setState(LifecycleState.FAILED);

      old_context = double 'old_context', :name => 'default', :path => '/',
        :parent => parent = double('parent')

      expect(parent).to receive(:add_child).with(context) #.ordered
      expect(parent).to receive(:remove_child).with(context) #.ordered

      expect(Thread).to receive(:new).and_yield

      app_holder = Trinidad::WebApp::Holder.new(create_web_app, old_context)
      roller.reload!(app_holder)
    end

    private

    def stub_logger(*levels)
      levels = [ :debug, :info, :error ] if levels.empty?
      levels = levels.inject({}) { |memo, level| memo[level] = nil; memo }
      allow(Trinidad::Lifecycle::Host::RollingReload).to receive(:logger).and_return logger = double('logger', levels)
      logger
    end

    def create_web_app(config = {})
      super(config.merge(:reload_strategy => :rolling))
    end

    describe 'Takeover' do

      Takeover = Trinidad::Lifecycle::Host::RollingReload::Takeover

      let(:new_context) { Trinidad::Tomcat::StandardContext.new }
      let(:old_context) { Trinidad::Tomcat::StandardContext.new }

      let(:takeover) { Takeover.new(old_context) }

      let(:after_start_event) do
        Trinidad::Tomcat::LifecycleEvent.new(new_context,
          Trinidad::Tomcat::Lifecycle::AFTER_START_EVENT, nil)
      end

      it "stops and destroys the (old) context" do
        expect(old_context).to receive(:stop).once.ordered
        expect(old_context).to receive(:destroy).once.ordered
        takeover.lifecycleEvent(after_start_event)
      end

      it "does not change context's name to the original one" do
        expect(old_context).to receive(:stop)
        expect(old_context).to receive(:destroy)
        old_context.name = 'foo'
        takeover.lifecycleEvent(after_start_event)
        new_context.name.should_not == 'foo'
      end

      work_dir = File.expand_path('work', MOCK_RACK_WEB_APP_DIR)

      before do
        FileUtils.mkdir work_dir unless File.exist?(work_dir)
      end

      after do
        FileUtils.rm_rf(work_dir) if File.exist?(work_dir)
      end

      it "does not delete working directory", :integration => true do
        #context = tomcat.addWebapp(web_app.context_path, web_app.web_app_dir)
        web_app = create_web_app :work_dir => work_dir, :root_dir => MOCK_RACK_WEB_APP_DIR
        old_context.name = 'default'
        old_context.path = '/'
        old_context.parent = tomcat.host
        old_context.addLifecycleListener config = Trinidad::Tomcat::ContextConfig.new
        old_context.addLifecycleListener web_app.define_lifecycle
        Trinidad::Tomcat::Tomcat.initWebappDefaults(old_context)
        old_context.start
        getServer(old_context).start
        #config.send(:getServer).start # make sure it's available @see ContextConfig#destroy

        takeover.lifecycleEvent(after_start_event)
        expect( File.exist?(work_dir) ).to be true
      end

      private

      def getServer(context)
        engine = context
        while engine && ! engine.is_a?(Trinidad::Tomcat::Engine)
          engine = engine.parent
        end
        return nil unless engine
        service = engine.service
        service ? service.server : nil
      end

    end

  end

end
