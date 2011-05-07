require File.dirname(__FILE__) + '/../spec_helper'
require 'optparse'

describe Trinidad::Extensions do

  before(:each) do
    @extensions = {:foo => {:bar => :bazz}}
  end

  it "configures the server with new stuff" do
    lambda {Trinidad::Extensions.configure_server_extensions(@extensions, nil)}.should_not raise_error
    lambda {Trinidad::Extensions.const_get(:FooServerExtension)}.should_not raise_error
  end

  it "configures the webapp with new stuff" do
    lambda {Trinidad::Extensions.configure_webapp_extensions(@extensions, nil, nil)}.should_not raise_error
    lambda {Trinidad::Extensions.const_get(:FooWebAppExtension)}.should_not raise_error
  end

  it "adds options to the command line parser" do
    options = {}
    parser = OptionParser.new
    lambda {
      Trinidad::Extensions.configure_options_extensions({:foo => {}}, parser, options)
    }.should_not raise_error

    lambda {
      parser.parse! ['--foo']
      options.has_key?(:foo).should be_true
    }.should_not raise_error
  end

  it "allows to override the tomcat's instance" do
    extensions = {:override_tomcat => {}}
    tomcat = Trinidad::Tomcat::Tomcat.new

    extended = Trinidad::Extensions.configure_server_extensions(extensions, tomcat)
    extended.should_not equal(tomcat)
  end

  it "ignores extensions that don't exist for that scope" do
    extensions = {:override_tomcat => {}}
    tomcat = Trinidad::Tomcat::Tomcat.new

    lambda {
      Trinidad::Extensions.configure_webapp_extensions(extensions, tomcat, nil)
    }.should_not raise_error
  end

  it "raises an error when the extension doesn't exist" do
    extensions = {:foo_bar => {}}
    tomcat = Trinidad::Tomcat::Tomcat.new

    lambda {
      Trinidad::Extensions.configure_webapp_extensions(extensions, tomcat, nil)
    }.should raise_error
  end
end
