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
      :web_app_dir => MOCK_WEB_APP_DIR})
      
    server.ssl_enabled?.should == true
  end
  
  it "should have ajp enabled when config param is a number" do
    server = Trinidad::Server.new({:ajp => {:port => 8009}})
     
    server.ajp_enabled?.should == true
  end
  
  it "should have a connector with https scheme" do
    server = Trinidad::Server.new({:ssl => {:port => 8443},
      :web_app_dir => MOCK_WEB_APP_DIR})
      
    server.tomcat.service.findConnectors().should have(1).connectors
    server.tomcat.service.findConnectors()[0].scheme.should == 'https'
  end
  
  it "should have an ajp connector enabled" do
    server = Trinidad::Server.new({:ajp => {:port => 8009}})
      
    server.tomcat.service.findConnectors().should have(1).connectors
    server.tomcat.service.findConnectors()[0].protocol.should == 'AJP/1.3'
  end

  it "loads one application for each option present into :web_apps" do
    server = Trinidad::Server.new({
      :web_apps => {
        :mock1 => {
          :context_path => '/mock1',
          :web_app_dir => MOCK_WEB_APP_DIR
        },
        :mock2 => {
          :web_app_dir => MOCK_WEB_APP_DIR
        },
        :default => {
          :web_app_dir => MOCK_WEB_APP_DIR
        }
      }
    })

    context_loaded = server.tomcat.host.findChildren()
    context_loaded.should have(3).web_apps
    
    expected = ['/mock1', '/mock2', '/']
    context_loaded.each do |context|
      expected.delete(context.getPath()).should == context.getPath()
    end
  end

  it "loads the default application from the current directory if :web_apps is not present" do
    server = Trinidad::Server.new({:web_app_dir => MOCK_WEB_APP_DIR})

    default_context_should_be_loaded(server.tomcat.host.findChildren())
  end
  
  it "loads the default application from the current directory using the rackup file if :web_apps is not present" do
    server = Trinidad::Server.new({
      :web_app_dir => MOCK_WEB_APP_DIR,
      :rackup => 'config.ru'
    })

    context = default_context_should_be_loaded(server.tomcat.host.findChildren())
    context.findParameter('rackup').gsub(/\s+/, ' ').should == "require 'rubygems' require 'sinatra'"
  end

  def default_context_should_be_loaded(children)
    children.should have(1).web_apps
    children[0].getDocBase().should == MOCK_WEB_APP_DIR
    children[0].getPath().should == '/'
    children[0]
  end
end
