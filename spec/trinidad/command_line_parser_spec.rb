require File.dirname(__FILE__) + '/../spec_helper'
require 'fakefs/safe'

describe Trinidad::CommandLineParser do
  subject { Trinidad::CommandLineParser }

  it "overrides classes option" do
    args = "--classes my_classes".split

    options = subject.parse(args)
    options[:classes_dir].should == 'my_classes'
  end

  it "overrides libs option with lib option" do
    args = "--lib my_libs".split

    options = subject.parse(args)
    options[:libs_dir].should == 'my_libs'
  end

  it "overrides libs option with jar option" do
    args = "--jars my_jars".split

    options = subject.parse(args)
    options[:libs_dir].should == 'my_jars'
  end

  it "uses config/trinidad.yml as the default configuration file name" do
    FakeFS.activate!
    begin
      File.open('config/trinidad.yml', 'w') {|io| io.write("---\n  :port: 8080") }
      options = subject.parse(['-f'])

      options[:config].should == 'config/trinidad.yml'
      options[:port].should == 8080
    ensure
      FakeFS.deactivate!
    end
  end

  it "overrides the config file when it's especified" do
    args = "-f #{File.join(MOCK_WEB_APP_DIR, 'tomcat.yml')}".split

    options = subject.parse(args)
    options[:environment].should == 'production'
  end

  it "adds default ssl port to options" do
    args = '--ssl'.split

    options = subject.parse(args)
    options[:ssl].should == {:port => 8443}
  end

  it "adds custom ssl port to options" do
    args = '--ssl 8843'.split

    options = subject.parse(args)
    options[:ssl].should == {:port => 8843}
  end

  it "adds ajp connection with default port to options" do
    args = '--ajp'.split

    options = subject.parse(args)
    options[:ajp].should == {:port => 8009}
  end

  it "adds ajp connection with coustom port to options" do
    args = '--ajp 8099'.split

    options = subject.parse(args)
    options[:ajp].should == {:port => 8099}
  end

  it "merges ajp options from the config file" do
    args = "--ajp 8099 -f #{File.join(MOCK_WEB_APP_DIR, 'tomcat.yml')}".split

    options = subject.parse(args)
    options[:ajp][:port].should == 8099
    options[:ajp][:secure].should == true
  end

  it "uses default rackup file to configure the server" do
    args = "--rackup".split
    options = subject.parse(args)
    options[:rackup].should == 'config.ru'
  end

  it "uses a custom rackup file if it's provided" do
    args = "--rackup custom_config.ru".split
    options = subject.parse(args)
    options[:rackup].should == 'custom_config.ru'
  end

  it "uses a custom public directory" do
    args = "--public web".split
    options = subject.parse(args)
    options[:public].should == 'web'
  end

  it "works on threadsafe mode using the shortcut" do
    args = '--threadsafe'.split
    options = subject.parse(args)
    options[:jruby_min_runtimes].should == 1
    options[:jruby_max_runtimes].should == 1
  end

  it "loads a given extension to add its options to the parser" do
    args = "--load foo --foo".split
    options = subject.parse(args)
    options.has_key?(:bar).should be_true

  end
end
