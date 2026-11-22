# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/docker/events'

describe MKIt::Container::Docker::Events do
  it 'yields the events of the stream as Container::Event' do
    client = mock('client')
    client.expects(:stream).with('/events').multiple_yields(
      [{ 'Type' => 'container', 'Action' => 'start', 'id' => 'abc', 'Actor' => { 'Attributes' => { 'name' => 'p1' } } }],
      [{ 'Type' => 'network', 'Action' => 'connect', 'Actor' => { 'Attributes' => { 'container' => 'abc' } } }]
    )
    got = []
    described_class.new(client).each { |e| got << e }
    assert(got.all? { |e| e.is_a?(MKIt::Container::Event) })
    assert_equal %i[container network], got.map(&:kind)
    assert_equal %w[abc abc], got.map(&:container_id)
  end
end
