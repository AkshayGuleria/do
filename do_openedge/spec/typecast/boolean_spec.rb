# encoding: utf-8

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require 'data_objects/spec/shared/typecast/boolean_spec'

describe 'DataObjects::Openedge with Boolean' do
  it_should_behave_like 'supporting Boolean'
  # TODO should we map smallint to boolean for derby ??
#  it_should_behave_like 'supporting Boolean autocasting'
end
