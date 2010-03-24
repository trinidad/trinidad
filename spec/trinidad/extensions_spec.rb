require File.dirname(__FILE__) + '/../spec_helper'
require 'optparse'

describe Trinidad::Extensions do
  include Trinidad::Extensions

  before do
    @gem_mock = OpenStruct.new
    @gem_mock.name = "trinidad_foo_extension"

    Gem::GemPathSearcher.any_instance.stubs(:find_all).returns([@gem_mock])
  end

  it "loads extensions from gems called 'trinidad-*-extension'" do
    extensions.should have(1).extension
  end

  it "filters the extensions for the command line parser" do
    command_line_parser_extensions.should have(1).extension
  end

  it "filters the extensions for the server" do
    server_extensions.should have(1).extension
  end

  it "filters the extensions for web applications" do
    webapp_extensions.should have(1).extension
  end

  it "gets the class for options addons" do
    extension = extensions.values.first

    extension.addon(:options).should_not be_nil
    extension.addon(:options).name.should == "Trinidad::FooOptionsAddon"
  end

  it "adds options to command line parser" do
    parser = OptionParser.new
    default_options = {}

    configure_parser_extensions(parser, default_options)
    ARGV = "--foo".split
    parser.parse!(ARGV)

    default_options.keys.should include(:foo)
  end

  it "configures the server with new stuff" do
    lambda {configure_server_extensions(nil, nil)}.should_not raise_error
  end

  it "configures the webapp with new stuff" do
    lambda {configure_webapp_extensions(nil, nil, nil)}.should_not raise_error
  end

  it "can be configured by extension name and type" do
    lambda {configure_extension_by_name_and_type("foo", :server, nil, nil)}.should_not raise_error
  end
end
