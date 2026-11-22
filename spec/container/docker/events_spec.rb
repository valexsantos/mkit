# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/docker/events'

describe MKIt::Container::Docker::Events do
  it 'yields the events of the stream' do
    client = mock('client')
    client.expects(:stream).with('/events').multiple_yields([{ 'Type' => 'container' }], [{ 'Type' => 'network' }])
    got = []
    described_class.new(client).each { |e| got << e['Type'] }
    assert_equal %w[container network], got
  end
end
