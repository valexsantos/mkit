# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/docker/networks'

describe MKIt::Container::Docker::Networks do
  let(:client) { mock('client') }
  let(:networks) { described_class.new(client) }

  it 'creates, attaches, detaches and removes' do
    client.expects(:post).with('/networks/create', 'Name' => 'mkit')
    client.expects(:post).with('/networks/n1/connect', 'Container' => 'c')
    client.expects(:post).with('/networks/n1/disconnect', 'Container' => 'c')
    client.expects(:delete).with('/networks/n1')
    networks.create('mkit')
    networks.attach('n1', 'c')
    networks.detach('n1', 'c')
    networks.remove('n1')
  end

  it 'finds networks and tells if they exist' do
    client.stubs(:get).with('/networks/mkit').returns('Id' => '1')
    client.stubs(:get).with('/networks/none').returns(nil)
    assert_equal '1', networks.find('mkit')['Id']
    assert networks.exists?('mkit')
    refute networks.exists?('none')
  end
end
