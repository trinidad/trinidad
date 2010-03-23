require File.dirname(__FILE__) + '/../spec_helper'
require 'optparse'

describe Trinidad::Extensions do
  include Trinidad::Extensions

  before do
    @gem_mock = OpenStruct.new
    @gem_mock.name = "trinidad-foo-extension"

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

  it "gets the class for options addons" do
    extension = extensions.first

    extension.options_addon.should_not be_nil
    extension.options_addon.name.should == "Trinidad::FooOptionsAddon"
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
    configure_server_extensions(nil, nil)
  end
end
