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
    ARGV = "-f #{File.join(File.dirname(__FILE__), '..', 'web_app_mock', 'tomcat.yml')}".split
    
    options = Trinidad::CommandLineParser.parse
    options[:environment].should == 'production'
  end
  
end