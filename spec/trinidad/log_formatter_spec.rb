require File.dirname(__FILE__) + '/../spec_helper'

describe Trinidad::LogFormatter do
  let(:formatter) { Trinidad::LogFormatter.new }

  let(:record) {
    OpenStruct.new({ :millis => 1000 * Time.utc(2011, 2, 5, 13, 45, 22).to_f,
                     :level => OpenStruct.new(:name => 'WARNING'),
                     :message => 'Nyan nyan nyan!' })
  }

  subject { formatter.format record }

  it { should == "2011-02-05 13:45:22 WARNING: Nyan nyan nyan!\n" }
end