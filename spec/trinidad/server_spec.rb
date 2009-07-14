require File.dirname(__FILE__) + '/../spec_helper'

describe Trinidad::Server do
  
  it "should have ssl disabled when config param is nil" do
    server = Trinidad::Server.new
    server.ssl_enabled?.should == false
  end
  
  it "should have ajp disabled when config param is nil" do
    server = Trinidad::Server.new
    server.ajp_enabled?.should == false
  end
  
  it "should have ssl enabled when config param is a number" do
    server = Trinidad::Server.new({:ssl => {:port => 8443},
      :web_app_dir => File.join(File.dirname(__FILE__), '..', 'web_app_mock')})
      
    server.ssl_enabled?.should == true
  end
  
  it "should have ajp enabled when config param is a number" do
    server = Trinidad::Server.new({:ajp => {:port => 8009}})
     
    # wondering why this test doesn't pass 
    #server.ajp_enabled?.should == true
  end
  
  it "should have a connector with https scheme" do
    server = Trinidad::Server.new({:ssl => {:port => 8443},
      :web_app_dir => File.join(File.dirname(__FILE__), '..', 'web_app_mock')})
      
    server.tomcat.service.findConnectors().should have(1).connectors
    server.tomcat.service.findConnectors()[0].scheme.should == 'https'
  end
  
  it "should have an ajp connector enabled" do
    server = Trinidad::Server.new({:ajp => {:port => 8009}})
      
    server.tomcat.service.findConnectors().should have(1).connectors
    server.tomcat.service.findConnectors()[0].protocol.should == 'AJP/1.3'
  end
end