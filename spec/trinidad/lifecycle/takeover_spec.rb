require File.dirname(__FILE__) + '/../../spec_helper'

describe "Trinidad::Lifecycle::Takeover" do
  let(:context) { mock }
  let(:old_context) {
    {:context => mock, :lock => true}
  }

  let(:start_event) do
    Trinidad::Tomcat::LifecycleEvent.new(context,
      Trinidad::Tomcat::Lifecycle::AFTER_START_EVENT, nil)
  end

  let(:listener) do
    Trinidad::Lifecycle::Takeover.new(old_context)
  end

  before do
    old_context[:context].expects(:stop).once
    old_context[:context].expects(:destroy).once
    expects_name_modification
  end

  it "change the context's name for the original one" do
    listener.lifecycleEvent(start_event)
  end

  it "removes the lock after the new context has taken over" do
    listener.lifecycleEvent(start_event)
    old_context.should_not include(:lock)
  end

  def expects_name_modification
    name = 'foo'
    context.expects(:"name=").once.with(name)
    old_context[:context].expects(:name).once.returns(name)
  end
end
