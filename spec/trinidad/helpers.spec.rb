require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Trinidad::Helpers do

  context 'to_url' do

    it 'handles file: paths' do
      url = Trinidad::Helpers.to_url 'file:/home/kares/workspace'
      expect( url.to_s ).to eql 'file:/home/kares/workspace'

      url = Trinidad::Helpers.to_url 'file:///home/kares/workspace'
      expect( url.to_s ).to eql 'file:/home/kares/workspace'

      url = Trinidad::Helpers.to_url 'file:///c:/Documents and Settings/home'
      expect( url.to_s ).to eql 'file:/c:/Documents and Settings/home'
    end

    it 'handles (escaped) file: paths' do
      url = Trinidad::Helpers.to_url 'file:/home/kares/workspace/space%20here'
      expect( url.to_s ).to eql 'file:/home/kares/workspace/space here'

      url = Trinidad::Helpers.to_url 'file:///C:/Documents%20and%20Settings/home'
      expect( url.to_s ).to eql 'file:/C:/Documents and Settings/home'
    end

    it 'returns file: URL for paths' do
      url = Trinidad::Helpers.to_url '/home/kares/workspace/file.txt'
      expect( url.to_s ).to eql 'file:/home/kares/workspace/file.txt'

      url = Trinidad::Helpers.to_url '/home/kares/workspace/file'
      expect( url.to_s ).to eql 'file:/home/kares/workspace/file'
    end

    it 'returns file: URL for relative paths' do
      url = Trinidad::Helpers.to_url 'workspace/jruby-rack'
      expect( url.to_s ).to eql "file:#{Dir.pwd}/workspace/jruby-rack"
    end

    #it 'handles jar:file: paths' do
    #  url = Trinidad::Helpers.to_url 'jar:file/opt/jruby-rack.jar!/jruby-rack.rb'
    #  expect( url.to_s ).to eql "jar:file/opt/jruby-rack.jar!/jruby-rack.rb"
    #end

    it 'handles windows style "c:" paths' do
      url = Trinidad::Helpers.to_url 'c:/Documents and Settings/root'
      expect( url.to_s ).to eql "file:/c:/Documents and Settings/root"

      url = Trinidad::Helpers.to_url 'C:/Documents and Settings/root/file.txt'
      expect( url.to_s ).to eql "file:/C:/Documents and Settings/root/file.txt"

      url = Trinidad::Helpers.to_url '/C:/Documents and Settings'
      expect( url.to_s ).to eql "file:/C:/Documents and Settings"
    end

  end

end
