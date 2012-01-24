require File.dirname(__FILE__) + '/../spec_helper'
require 'ostruct'

describe Trinidad::LogFormatter do
  let(:formatter) { Trinidad::LogFormatter.new }
  let(:time) { Time.utc(2011, 2, 5, 13, 45, 22) }

  let(:record) {
    OpenStruct.new({ :millis => 1000 * time.gmtime.to_f,
                     :level => OpenStruct.new(:name => 'WARNING'),
                     :message => 'Nyan nyan nyan!' })
  }

  subject { formatter.format record }

  it { should == ("2011-02-05 %s WARNING: Nyan nyan nyan!\n" % time.strftime('%H:%M:%S')) }
end
