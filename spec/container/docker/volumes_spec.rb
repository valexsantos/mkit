# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/docker/volumes'

describe MKIt::Container::Docker::Volumes do
  let(:client) { mock('client') }
  let(:volumes) { described_class.new(client) }

  it 'creates, finds and removes' do
    client.expects(:post).with('/volumes/create', 'Name' => 'v')
    client.expects(:get).with('/volumes/v').returns('Name' => 'v')
    client.expects(:delete).with('/volumes/v')
    volumes.create('v')
    assert_equal 'v', volumes.find('v')['Name']
    volumes.remove('v')
  end
end
