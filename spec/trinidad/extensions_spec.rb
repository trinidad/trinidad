require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Trinidad::Extensions do

  let(:tomcat) { org.apache.catalina.startup.Tomcat.new }
  let(:context) { Trinidad::Tomcat::StandardContext.new }

  before :all do
    Trinidad::Extensions.module_eval do
      def self.load_extension(name)
        load "trinidad_#{name}_extension.rb"
      end
    end
  end

  after :all do
    Trinidad::Extensions.module_eval do
      def self.load_extension(name)
        require "trinidad_#{name}_extension"
      end
    end
  end

  after do
    [ :FooServerExtension, :FooWebAppExtension ].each do |const|
      if Trinidad::Extensions.const_defined?(const)
        Trinidad::Extensions.send :remove_const, const
      end
    end
  end

  it "configures the server with new stuff" do
    options = { :bar => :bazz }
    def options.dup; self; end # hack dup

    extensions = { :foo => options } # fixtures/trinidad_foo_extension.rb
    Trinidad::Extensions.configure_server_extensions(extensions, tomcat)
    expect( options[:foo] ).to eql 'foo_server_extension'
    expect( Trinidad::Extensions.const_get(:FooServerExtension) ).to_not be nil
  end

  it "configures the webapp with new stuff" do
    extensions = { :foo => { :bar => :bazz } } # fixtures/trinidad_foo_extension.rb
    Trinidad::Extensions.configure_webapp_extensions(extensions, tomcat, context)
    expect( context.getDocBase ).to eql 'foo_web_app_extension'
    expect( Trinidad::Extensions.const_get(:FooWebAppExtension) ).to_not be nil
  end

  it "configures the webapp with new stuff (backward compatible)" do
    extensions = { :foo_old => {} } # fixtures/trinidad_foo_old_extension.rb
    Trinidad::Extensions.configure_webapp_extensions(extensions, tomcat, context)
    expect( context.getDocBase ).to eql 'foo_old_web_app_extension'
  end

  it "skips the webapp extension with false" do
    extensions = { :foo => false }
    Trinidad::Extensions.configure_webapp_extensions(extensions, tomcat, context)
    expect( context.getDocBase ).to_not eql 'foo_web_app_extension'
    expect( Trinidad::Extensions.const_defined?(:FooWebAppExtension) ).to be false
  end

  it "configures with nil options" do
    extensions = { :foo => nil } # fixtures/trinidad_foo_extension.rb
    Trinidad::Extensions.configure_server_extensions(extensions, tomcat)
  end

  it "adds options to the command line parser" do
    require 'optparse'
    options = {}
    parser = OptionParser.new
    extensions = { :foo => {} } # fixtures/trinidad_foo_extension.rb
    Trinidad::Extensions.configure_options_extensions(extensions, parser, options)

    parser.parse! ['--foo']
    options[:foo].should be true
  end

  it "allows to override the tomcat's instance" do
    extensions = { :override => {} } # fixtures/trinidad_override_extension.rb

    extended = Trinidad::Extensions.configure_server_extensions(extensions, tomcat)
    expect( extended ).to_not eql(tomcat)
  end

  it "ignores extensions that don't exist for that scope" do
    extensions = { :override => {} } # fixtures/trinidad_override_extension.rb

    Trinidad::Extensions.configure_webapp_extensions(extensions, tomcat, nil)
  end

  it "ignores extension but warns about it when it doesn't exist" do
    extensions = { :missing => {} }

    expect( Trinidad::Helpers ).to receive(:warn)
    Trinidad::Extensions.configure_webapp_extensions(extensions, tomcat, nil)
  end

end