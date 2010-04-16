require File.dirname(__FILE__) + '/../spec_helper'

describe Trinidad::CommandLineParser do
  it "should override classes option" do
    ARGV = "--classes my_classes".split

    options = Trinidad::CommandLineParser.parse
    options[:classes_dir].should == 'my_classes'
  end

  it "should override libs option with lib option" do
    ARGV = "--lib my_libs".split

    options = Trinidad::CommandLineParser.parse
    options[:libs_dir].should == 'my_libs'
  end

  it "should override libs option with jar option" do
    ARGV = "--jars my_jars".split

    options = Trinidad::CommandLineParser.parse
    options[:libs_dir].should == 'my_jars'
  end

  it "should override the config file when it's especified" do
    ARGV = "-f #{File.join(MOCK_WEB_APP_DIR, 'tomcat.yml')}".split

    options = Trinidad::CommandLineParser.parse
    options[:environment].should == 'production'
  end

  it "should add default ssl port to options" do
    ARGV = '--ssl'.split

    options = Trinidad::CommandLineParser.parse
    options[:ssl].should == {:port => 8443}
  end

  it "should add custom ssl port to options" do
    ARGV = '--ssl 8843'.split

    options = Trinidad::CommandLineParser.parse
    options[:ssl].should == {:port => 8843}
  end

  it "should add ajp connection with default port to options" do
    ARGV = '--ajp'.split

    options = Trinidad::CommandLineParser.parse
    options[:ajp].should == {:port => 8009}
  end

  it "should add ajp connection with coustom port to options" do
    ARGV = '--ajp 8099'.split

    options = Trinidad::CommandLineParser.parse
    options[:ajp].should == {:port => 8099}
  end

  it "should merge ajp options from the config file" do
    ARGV = "--ajp 8099 -f #{File.join(MOCK_WEB_APP_DIR, 'tomcat.yml')}".split

    options = Trinidad::CommandLineParser.parse
    options[:ajp][:port].should == 8099
    options[:ajp][:secure].should == true
  end

  it "uses default rackup file to configure the server" do
    ARGV = "--rackup".split
    options = Trinidad::CommandLineParser.parse
    options[:rackup].should == 'config.ru'
  end

  it "uses a custom rackup file if it's provided" do
    ARGV = "--rackup custom_config.ru".split
    options = Trinidad::CommandLineParser.parse
    options[:rackup].should == 'custom_config.ru'
  end

  it "uses a custom public directory" do
    ARGV = "--public web".split
    options = Trinidad::CommandLineParser.parse
    options[:public].should == 'web'
  end

  it "works on threadsafe mode using the shortcut" do
    ARGV = '--threadsafe'.split
    options = Trinidad::CommandLineParser.parse
    options[:jruby_min_runtimes].should == 1
    options[:jruby_max_runtimes].should == 1
  end
end
