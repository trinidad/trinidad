require File.expand_path('./spec_helper', File.dirname(__FILE__))

describe Trinidad do

  context "jars" do

    it "exposes Tomcat" do
      expect { Trinidad::Tomcat }.to_not raise_error
      expect( Trinidad::Tomcat.new ).to be_a org.apache.catalina.startup.Tomcat
    end

    it "exposes real Tomcat (startup package)" do
      expect { Trinidad::Tomcat::Tomcat }.to_not raise_error
      expect( Trinidad::Tomcat::Tomcat.new ).to be_a org.apache.catalina.startup.Tomcat
    end

    it "exposes catalina API" do
      expect { Trinidad::Tomcat::StandardContext }.to_not raise_error
      expect { Trinidad::Tomcat::Context }.to_not raise_error
      expect( Trinidad::Tomcat::StandardContext.new ).to be_a org.apache.catalina.Context
    end

    it "exposes Connector" do
      expect { Trinidad::Tomcat::Connector }.to_not raise_error
      expect( Trinidad::Tomcat::Connector ).to be org.apache.catalina.connector.Connector
    end

    it "exposes ContextName" do
      expect { Trinidad::Tomcat::ContextName }.to_not raise_error
    end

  end

end