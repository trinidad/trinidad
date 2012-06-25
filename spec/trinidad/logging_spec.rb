require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Trinidad::Logging do
  
  JUL = Java::JavaUtilLogging
  
  before do
    @root_logger = JUL::Logger.getLogger('')
    @root_level = @root_logger.level
    @root_handlers = @root_logger.handlers.to_a
  end
  
  after do
    @root_logger.level = @root_level # JUL::Level::INFO
    @root_logger.handlers.each { |handler| @root_logger.removeHandler(handler) }
    @root_handlers.each { |handler| @root_logger.addHandler(handler) }    
  end
  
  it "configures logging during server creation" do
    Trinidad::Server.new({ :log => 'WARNING', :web_app_dir => MOCK_WEB_APP_DIR })
    
    logger = JUL::Logger.getLogger('')
    logger.level.should == JUL::Level::WARNING
    handlers = logger.handlers.select { |handler| handler.is_a?(JUL::ConsoleHandler) }
    handlers.size.should == 2
    handlers.each { |handler| handler.level.should == logger.level }
    handlers.each { |handler| handler.formatter.should be_a Trinidad::Logging::Formatter }
  end
  
  after { Trinidad.configuration = nil }
  
end

describe Trinidad::Logging::Formatter do
  
  it "formats time (according to local time zone)" do
    time = Time.local(2011, 2, 5, 13, 45, 22)
    record = JUL::LogRecord.new JUL::Level::WARNING, nil
    record.message = 'Nyan nyan nyan!'
    record.millis = time.to_java.time
    
    formatter = new_formatter("yyyy-MM-dd HH:mm:ss Z")
    offset = time_offset(time)
    formatter.format(record).should == "2011-02-05 13:45:22 #{offset} WARNING: Nyan nyan nyan!\n"
  end
  
  it "formats time (according to UTC time zone)" do
    time = Time.utc(2011, 2, 5, 13, 45, 22)
    record = JUL::LogRecord.new JUL::Level::INFO, "basza meg a zold tucsok"
    record.millis = time.to_java.time
    
    formatter = new_formatter("yyyy-MM-dd HH:mm:ss Z", 0)
    formatter.format(record).should == "2011-02-05 13:45:22 +0000 INFO: basza meg a zold tucsok\n"
    
    formatter = new_formatter("yyyy-MM-dd HH:mm:ss Z", 'GMT')
    formatter.format(record).should == "2011-02-05 13:45:22 +0000 INFO: basza meg a zold tucsok\n"
  end

  it "does not add new line to message if already present" do
    record = JUL::LogRecord.new JUL::Level::INFO, msg = "basza meg a zold tucsok\n"
    record.millis = java.lang.System.current_time_millis
    
    formatter = new_formatter
    log_msg = formatter.format(record)
    log_msg[-(msg.size + 6)..-1].should == "INFO: basza meg a zold tucsok\n"
  end
  
  it "prints thrown exception if present" do
    record = JUL::LogRecord.new JUL::Level::SEVERE, nil
    record.message = "Bazinga!"
    record.thrown = java.lang.RuntimeException.new("42")
    
    formatter = new_formatter
    formatter.format(record).should =~ /.*? SEVERE: Bazinga!\n/
    lines = formatter.format(record).split("\n")
    lines[1].should == 'java.lang.RuntimeException: 42'
    lines.size.should > 3
    lines[2...-1].each { |line| line.should =~ /at .*?(.*?)/ } # at org.jruby.RubyProc.call(RubyProc.java:270)
  end
  
  private
  
  def new_formatter(*args)
    Trinidad::Logging::Formatter.new(*args)
  end
  
  def time_offset(time)
    offset = time.utc_offset / 3600
    format "%+03d%02d", offset, (offset * 100) % 100
  end
  
end

describe "Trinidad::LogFormatter" do
  it "still works" do
    Trinidad::LogFormatter.should == Trinidad::Logging::Formatter
  end
end
