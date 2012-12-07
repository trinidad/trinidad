require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Trinidad::Extensions do

  let(:tomcat) { org.apache.catalina.startup.Tomcat.new }
  let(:context) { Trinidad::Tomcat::StandardContext.new }
  
  it "configures the server with new stuff" do
    options = { :bar => :bazz }
    def options.dup; self; end # hack dup
    
    extensions = { :foo => options } # fixtures/trinidad_foo_extension.rb
    lambda {
      Trinidad::Extensions.configure_server_extensions(extensions, tomcat)
    }.should_not raise_error
    
    options[:foo].should == 'foo_server_extension'
    
    lambda {
      Trinidad::Extensions.const_get(:FooServerExtension)
    }.should_not raise_error
  end

  it "configures the webapp with new stuff" do
    extensions = { :foo => { :bar => :bazz } } # fixtures/trinidad_foo_extension.rb
    lambda {
      Trinidad::Extensions.configure_webapp_extensions(extensions, tomcat, context)
    }.should_not raise_error
    
    context.getDocBase.should == 'foo_web_app_extension'
    
    lambda {
      Trinidad::Extensions.const_get(:FooWebAppExtension)
    }.should_not raise_error
  end

  it "configures the webapp with new stuff (backward compatible)" do
    extensions = { :foo_old => {} } # fixtures/trinidad_foo_old_extension.rb
    lambda {
      Trinidad::Extensions.configure_webapp_extensions(extensions, tomcat, context)
    }.should_not raise_error
    
    context.getDocBase.should == 'foo_old_web_app_extension'
  end
  
  it "configures with nil options" do
    extensions = { :foo => nil } # fixtures/trinidad_foo_extension.rb
    lambda {
      Trinidad::Extensions.configure_server_extensions(extensions, tomcat)
    }.should_not raise_error
  end
  
  it "adds options to the command line parser" do
    require 'optparse'
    options = {}
    parser = OptionParser.new
    extensions = { :foo => {} } # fixtures/trinidad_foo_extension.rb
    lambda {
      Trinidad::Extensions.configure_options_extensions(extensions, parser, options)
    }.should_not raise_error

    lambda {
      parser.parse! ['--foo']
      options[:foo].should be true
    }.should_not raise_error
  end

  it "allows to override the tomcat's instance" do
    extensions = { :override => {} } # fixtures/trinidad_override_extension.rb

    extended = Trinidad::Extensions.configure_server_extensions(extensions, tomcat)
    extended.should_not equal(tomcat)
  end

  it "ignores extensions that don't exist for that scope" do
    extensions = { :override => {} } # fixtures/trinidad_override_extension.rb
    
    lambda {
      Trinidad::Extensions.configure_webapp_extensions(extensions, tomcat, nil)
    }.should_not raise_error
  end

  it "ignores extension but warns about it when it doesn't exist" do
    extensions = { :missing => {} }

    Trinidad::Helpers.expects(:warn)
    lambda {
      Trinidad::Extensions.configure_webapp_extensions(extensions, tomcat, nil)
    }.should_not raise_error
  end
  
end