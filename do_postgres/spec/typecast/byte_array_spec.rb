# encoding: utf-8

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require 'data_objects/spec/shared/typecast/byte_array_spec'

describe 'DataObjects::Postgres with ByteArray' do
  it_should_behave_like 'supporting ByteArray'

  describe 'additional byte array (file) tests' do

    before do
      @connection = DataObjects::Connection.new(CONFIG.uri)
      @reader = @connection.create_command("SELECT size, sha256, data FROM pdfs WHERE id = ?").execute_reader(1)
      @reader.next!
      @values = @reader.values
      @size, @sha256, @data = @values
    end

    after do
      @reader.close
      @connection.close
    end

    it 'should return the right size' do
      @size.should == @data.size
    end

    it 'should return the correct data' do
      @sha256.should == Digest::SHA256.new.hexdigest(@data)
    end

  end
end
