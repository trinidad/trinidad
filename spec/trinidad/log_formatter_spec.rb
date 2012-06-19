require File.dirname(__FILE__) + '/../spec_helper'
require 'ostruct'

describe Trinidad::LogFormatter do

  JUL = Java::JavaUtilLogging
  
  it "formats time (according to local time zone)" do
    time = Time.local(2011, 2, 5, 13, 45, 22)
    record = JUL::LogRecord.new JUL::Level::WARNING, nil
    record.message = 'Nyan nyan nyan!'
    record.millis = time.to_java.time
    
    formatter = Trinidad::LogFormatter.new("yyyy-MM-dd HH:mm:ss Z")
    offset = time_offset(time)
    formatter.format(record).should == "2011-02-05 13:45:22 #{offset} WARNING: Nyan nyan nyan!\n"
  end
  
  it "formats time (according to UTC time zone)" do
    time = Time.utc(2011, 2, 5, 13, 45, 22)
    record = JUL::LogRecord.new JUL::Level::INFO, "basza meg a zold tucsok"
    record.millis = time.to_java.time
    
    formatter = Trinidad::LogFormatter.new("yyyy-MM-dd HH:mm:ss Z", 0)
    formatter.format(record).should == "2011-02-05 13:45:22 +0000 INFO: basza meg a zold tucsok\n"
    
    formatter = Trinidad::LogFormatter.new("yyyy-MM-dd HH:mm:ss Z", 'GMT')
    formatter.format(record).should == "2011-02-05 13:45:22 +0000 INFO: basza meg a zold tucsok\n"
  end

  it "does not add new line to message if already present" do
    record = JUL::LogRecord.new JUL::Level::INFO, msg = "basza meg a zold tucsok\n"
    record.millis = java.lang.System.current_time_millis
    
    formatter = Trinidad::LogFormatter.new
    log_msg = formatter.format(record)
    log_msg[-(msg.size + 6)..-1].should == "INFO: basza meg a zold tucsok\n"
  end
  
  it "prints thrown exception if present" do
    record = JUL::LogRecord.new JUL::Level::SEVERE, nil
    record.message = "Bazinga!"
    record.thrown = java.lang.RuntimeException.new("42")
    
    formatter = Trinidad::LogFormatter.new
    formatter.format(record).should =~ /.*? SEVERE: Bazinga!\n/
    lines = formatter.format(record).split("\n")
    lines[1].should == 'java.lang.RuntimeException: 42'
    lines.size.should > 3
    lines[2...-1].each { |line| line.should =~ /at .*?(.*?)/ } # at org.jruby.RubyProc.call(RubyProc.java:270)
  end
  
  private
  
  def time_offset(time)
    offset = time.utc_offset / 3600
    format "%+03d%02d", offset, (offset * 100) % 100
  end
  
end
