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

  it "creates a new context configuration with the default web.xml" do
    @listener.clean_context_configuration(@context)
    config = @context.find_lifecycle_listeners.select do |listener|
      listener.instance_of? Trinidad::Tomcat::ContextConfig
    end

    config.should have(1).listener
    config[0].default_web_xml.should == Trinidad::Tomcat::Constants::DefaultWebXml
  end
end
