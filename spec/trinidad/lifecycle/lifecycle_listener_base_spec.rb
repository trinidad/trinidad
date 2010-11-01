require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Trinidad::Lifecycle::Base do
  before do
    @context = Trinidad::Tomcat::Tomcat.new.add_webapp('/', MOCK_WEB_APP_DIR)
    Trinidad::Tomcat::Tomcat.init_webapp_defaults(@context)

    @options = {
        :web_app_dir => MOCK_WEB_APP_DIR,
        :environment => 'test',
        :log => 'INFO'
    }
    @webapp = Trinidad::WebApp.new({}, @options)
    @listener = Trinidad::Lifecycle::Base.new(@webapp)
  end

  after do
    FileUtils.rm_rf(File.expand_path('../../../log', __FILE__))
    FileUtils.rm_rf(File.join(MOCK_WEB_APP_DIR, 'log'))
  end

  it "should remove the context default configurations" do
    @listener.remove_defaults(@context)

    @context.welcome_files.should have(0).files

    @context.find_child('jsp').should be_nil

    @context.process_tlds.should be_false
    @context.xml_validation.should be_false
  end

  it "creates the log file according with the environment if it doesn't exist" do
    configure_logging(nil)
    File.exist?(File.join(MOCK_WEB_APP_DIR, 'log', 'test.log')).should be_true
  end

  it "uses the specified log level when it's valid" do
    configure_logging('WARNING')

    logger = java.util.logging.Logger.get_logger("")
    logger.level.to_s.should == 'WARNING'
  end

  it "uses INFO as default log level when it's invalid" do
    configure_logging('FOO')

    logger = java.util.logging.Logger.get_logger("")
    logger.level.to_s.should == 'INFO'
  end

  it "configures application logging once" do
    logger = java.util.logging.Logger.get_logger("")

    current_handlers = logger.handlers.size
    @listener.configure_logging
    logger.handlers.should have(current_handlers + 1).handlers

    @listener.configure_logging
    logger.handlers.should have(current_handlers + 1).handlers
  end

  def configure_logging(level)
    @options[:log] = level
    @listener = Trinidad::Lifecycle::Base.new(Trinidad::WebApp.new({}, @options))
    @listener.configure_logging
  end
end
