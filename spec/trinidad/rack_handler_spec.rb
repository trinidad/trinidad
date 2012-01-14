require 'spec_helper'

describe Rack::Handler::Trinidad do
  it "registers the trinidad handler" do
    Rack::Handler.get(:trinidad).should == described_class
  end

  it "turns the threads option into jruby min/max runtimes" do
    opts = described_class.parse_options({:threads => '2:3'})
    opts[:jruby_min_runtimes].should == 2
    opts[:jruby_max_runtimes].should == 3
  end

  it "uses localhost:3000 as default host:port" do
    opts = described_class.parse_options
    opts[:address].should == 'localhost'
    opts[:port].should == 3000
  end

  it "accepts host:port or address:port as options" do
    opts = described_class.parse_options({:host => 'foo', :port => 4000})
    opts[:address].should == 'foo'
    opts[:port].should == 4000

    opts = described_class.parse_options({:address => 'bar', :port => 5000})
    opts[:address].should == 'bar'
    opts[:port].should == 5000
  end

  it "creates a servlet for the app" do
    servlet = described_class.create_servlet(nil)
    servlet.context.server_info.should == 'Trinidad'
    servlet.dispatcher.should_not be_nil
  end
end
