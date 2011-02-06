require File.dirname(__FILE__) + '/../../spec_helper'

describe "Trinidad::Lifecycle::Host" do
  let(:monitor) { File.expand_path('restart.txt', MOCK_WEB_APP_DIR) }
  let(:app) { mock }

  let(:start_event) do
    Trinidad::Tomcat::LifecycleEvent.new(app,
      Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT, nil)
  end

  let(:periodic_event) do
    Trinidad::Tomcat::LifecycleEvent.new(app,
      Trinidad::Tomcat::Lifecycle::PERIODIC_EVENT, nil)
  end

  let(:listener) do
    Trinidad::Lifecycle::Host.new({
      :context => app,
      :monitor => monitor}
    )
  end

  after { FileUtils.rm monitor }

  it "creates the monitor file when receives a before start event" do
    File.exist?(monitor).should be_false
    listener.lifecycleEvent(start_event)
    File.exist?(monitor).should be_true
  end

  it "does not create the monitor if already exists" do
    file = File.new(monitor, File::CREAT|File::TRUNC)
    mtime = file.mtime
    sleep(1)

    listener.lifecycleEvent(start_event)
    File.mtime(monitor).should == mtime
  end

  it "reloads contexts when the monitor is modified on PERIODIC events" do
    app.expects(:reload).once

    listener.lifecycleEvent start_event
    sleep(1)

    File.new(monitor, File::CREAT|File::TRUNC)
    listener.lifecycleEvent periodic_event
  end
end
