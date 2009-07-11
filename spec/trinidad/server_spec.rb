require File.dirname(__FILE__) + '/../spec_helper'

describe Trinidad::Server do
  
  it "should have ssl disabled when config param is nil" do
    server = Trinidad::Server.new
    server.ssl_enabled?.should == false
  end
  
  it "should have ssl disabled when config param is not a number" do
    server = Trinidad::Server.new({:ssl => true})
    server.ssl_enabled?.should == false
  end
  
  it "should have ssl enabled when config param is a number" do
    server = Trinidad::Server.new({:ssl => 8443,
      :web_app_dir => File.join(File.dirname(__FILE__), '..', 'web_app_mock')})
    server.ssl_enabled?.should == true
  end
  
  it "should have two connectors when ssl is enabled" do
    server = Trinidad::Server.new({:ssl => 8443,
      :web_app_dir => File.join(File.dirname(__FILE__), '..', 'web_app_mock')})
      
    server.tomcat.service.findConnectors().should have(1).connectors
    server.tomcat.service.findConnectors()[0].scheme.should == 'https'
  end
end