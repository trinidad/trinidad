require File.dirname(__FILE__) + '/../../spec_helper'

describe Trinidad::Lifecycle::War do
  before do
    @context = Trinidad::Tomcat::Tomcat.new.add_webapp('/', MOCK_WEB_APP_DIR)
    @listener = Trinidad::Lifecycle::War.new(Trinidad::WebApp.new({}, {}))
  end

  it "configures the war classloader" do
    @listener.configure_class_loader(@context)
    @context.loader.should_not be_nil
  end
end
