require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fakeapp'

include FakeApp

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
    FakeFS do
      create_default_config_file
      ['', '-f'].each do |opt|
        options = subject.parse([opt])

        options[:config].should == File.expand_path('config/trinidad.yml')
        options[:port].should == 8080
      end
    end
  end

  it "overrides the config file when it's especified" do
    FakeFS do
      create_custom_config_file
      args = "-f config/tomcat.yml".split

      options = subject.parse(args)
      options[:environment].should == 'production'
    end
  end

  it "allows erb substitution in the configuration file" do
    FakeFS do
      create_erb_config_file
      options = subject.parse(['-f'])

      options[:port].should == 8300
    end
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
    FakeFS do
      create_custom_config_file
      args = "--ajp 8099 -f config/tomcat.yml".split

      options = subject.parse(args)
      options[:ajp][:port].should == 8099
      options[:ajp][:secure].should == true
    end
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

  it "loads the given extensions to add its options to the parser" do
    args = "--load foo,bar --foo".split
    options = subject.parse(args)
    options.has_key?(:foo).should be_true
    options.has_key?(:bar).should be_true
  end

  it "adds the application directory path with the option --dir" do
    args = "--dir #{MOCK_WEB_APP_DIR}".split
    subject.parse(args)[:web_app_dir].should == MOCK_WEB_APP_DIR
  end

  it "accepts the option --address to set the trinidad's host name" do
    args = "--address trinidad.host".split
    subject.parse(args)[:address].should == 'trinidad.host'
  end

  it "accepts the option --log to set the logging level" do
    args = '--log WARNING'.split
    subject.parse(args)[:log].should == 'WARNING'
  end

  it "accepts the option --apps to set the applications base directory" do
    args = '--apps foo'.split
    subject.parse(args)[:apps_base].should == 'foo'
  end

  it "loads the configuration file from the web app directory if the option is present" do
    args = "-d #{MOCK_WEB_APP_DIR} -f tomcat.yml".split
    options = subject.parse(args)

    options[:config].should == File.expand_path('tomcat.yml', MOCK_WEB_APP_DIR)
    options[:port].should == 4000
  end

  it "can modify the monitor file for hot deploys" do
    args = "--monitor tmp/foo.txt".split
    subject.parse(args)[:monitor].should == 'tmp/foo.txt'
  end
end
