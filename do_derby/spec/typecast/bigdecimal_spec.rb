# encoding: utf-8

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require 'data_objects/spec/typecast/bigdecimal_spec'

describe 'DataObjects::Derby with BigDecimal' do
  it_should_behave_like 'supporting BigDecimal'
end
