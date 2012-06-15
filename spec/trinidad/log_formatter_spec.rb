require File.dirname(__FILE__) + '/../spec_helper'
require 'ostruct'

describe Trinidad::LogFormatter do
  
  before do
    @time = Time.local(2011, 2, 5, 13, 45, 22)
  end

  let(:record) {
    OpenStruct.new({ :millis => 1000 * @time.gmtime.to_f,
                     :level => OpenStruct.new(:name => 'WARNING'),
                     :message => 'Nyan nyan nyan!' })
  }

  it "formats time (according to local time zone)" do
    formatter = Trinidad::LogFormatter.new("yyyy-MM-dd HH:mm:ss Z")
    offset = time_offset(@time)
    formatter.format(record).should == "2011-02-05 13:45:22 #{offset} WARNING: Nyan nyan nyan!\n"
  end

  it "formats time (according to UTC time zone)" do
    @time = Time.utc(2011, 2, 5, 13, 45, 22)
    formatter = Trinidad::LogFormatter.new("yyyy-MM-dd HH:mm:ss Z", 0)
    formatter.format(record).should == "2011-02-05 13:45:22 +0000 WARNING: Nyan nyan nyan!\n"
    
    formatter = Trinidad::LogFormatter.new("yyyy-MM-dd HH:mm:ss Z", 'GMT')
    formatter.format(record).should == "2011-02-05 13:45:22 +0000 WARNING: Nyan nyan nyan!\n"
  end
  
  private
  
  def time_offset(time)
    offset = time.utc_offset / 3600
    format "%+03d%02d", offset, (offset * 100) % 100
  end
  
end
