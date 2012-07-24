require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Trinidad::Configuration do
  
  before do
    Trinidad.configuration = nil
  end
  
  it "configures with defaults" do
    config = Trinidad::Configuration.new
    config[:port].should == 3000
    config[:address].should == 'localhost'
    config[:environment].should == 'development'
  end

  it "has accessors and []= for common options" do
    config = Trinidad::Configuration.new
    config.port = 5000
    config['port'].should == 5000
    config[:address] = '127.0.0.1'
    config.address.should == '127.0.0.1'
    config['environment'] = 'production'
    config.environment.should == 'production'
  end
  
  it "sets up a global configuration instance on configure" do
    config = Trinidad.configure({ :port => 4000 })
    config.should be_a Trinidad::Configuration
    config[:port].should == 4000
    config[:address].should == 'localhost'
    
    Trinidad.configuration.should_not be nil
    Trinidad.configuration.should == config
  end

  it "allows custom options to be specified" do
    config = Trinidad::Configuration.new :custom_option1 => 1
    config[:custom_option1].should == 1
    config[:custom_option2] = '2'
    config[:custom_option2].should == '2'
  end
  
  it "(deep) merges provided hashes with defaults on configure" do
    config1 = { 
      :port => 1000, 
      :address => 'local.host',
      :http => { 'acceptCount' => 420, :bufferSize => 1024 }
    }
    config2 = { 
      'port' => 2000,
      'environment' => 'production',
      'http' => { :'connectionTimeout' => '30000', 'bufferSize' => 1025 }
    }
 
    config = Trinidad.configure!(config1, config2)
    config[:port].should == 2000
    config['address'].should == 'local.host'
    config.environment.should == 'production'
    config[:http].should == { 
      :acceptCount => 420, 
      :bufferSize => 1025,
      :connectionTimeout => '30000'
    }
  end
  
  it "(deep) symbolizes nested arrays of hashes on configure" do
    config1 = { :port => 1000 }
    config2 = {
      'web_apps' => { 
        'default' => { 
          'extensions' => { 
            'mysql_dbpool' => [
              { 'driver' => 'foo', 'host' => 'foo.net' },
              { 'driver' => 'bar', 'host' => 'bar.net' },
              42
            ]
          }
        }
      }
    }
 
    config = Trinidad.configure!(config1, config2)
    config[:web_apps].should_not be nil
    config[:web_apps][:default][:extensions].should_not be nil
    config[:web_apps][:default][:extensions][:mysql_dbpool].should == [
      { :driver => 'foo', :host => 'foo.net' },
      { :driver => 'bar', :host => 'bar.net' },
      42
    ]
  end
  
end