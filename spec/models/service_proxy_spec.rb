# frozen_string_literal: true

require 'spec_helper'
require 'support/in_memory_db'
require 'support/logger'
require 'mkit/app/model/service'

ActiveRecord::Schema.define do
  create_table :services, force: true do |t|
    t.string :name
    t.string :pods_network
  end
end

describe Service do
  let(:service) { described_class.new(name: 'web') }

  def pod(name, ip)
    OpenStruct.new(name: name, ip: ip)
  end

  describe '#proxy_pods and #routable?' do
    it 'only routes to pods with an ip' do
      service.stubs(:pod).returns([pod('a', '10.0.0.5'), pod('b', nil), pod('c', ''), pod('d', '10.0.0.6')])
      assert_equal %w[a d], service.proxy_pods.map(&:name)
      assert service.routable?
    end

    it 'is not routable without pods' do
      service.stubs(:pod).returns([])
      refute service.routable?
    end

    it 'is not routable when no pod has an ip (e.g. the containers do not exist)' do
      service.stubs(:pod).returns([pod('a', nil), pod('b', '')])
      refute service.routable?
    end

    it 'a stopped pod counts, it keeps its last ip' do
      service.stubs(:pod).returns([pod('stopped', '10.0.0.5')])
      assert service.routable?
    end
  end

  describe '#proxy_filename' do
    it 'is built from the last octet of the lease ip and the name' do
      service.stubs(:lease).returns(OpenStruct.new(ip: '10.210.198.12'))
      assert_equal '0012_web.cfg', service.proxy_filename
    end
  end

  describe 'proxy config' do
    let(:frontend) do
      OpenStruct.new(name: 'in', port: '80', 'ssl?': false, mode: 'http', options: [], bind_options: [],
                     default_backend: 'app')
    end
    let(:backend) do
      OpenStruct.new(name: 'app', mode: 'http', load_balance: 'roundrobin', options: [], port: '8080',
                     bind_options: ['check'])
    end

    before do
      service.stubs(:lease).returns(OpenStruct.new(ip: '10.210.198.12'))
      service.stubs(:ingress).returns(OpenStruct.new(frontends: [frontend], backends: [backend]))
    end

    it 'has a server line for each pod with an ip, none for the others' do
      service.stubs(:pod).returns([pod('a', '10.0.0.5'), pod('b', nil), pod('c', '10.0.0.6')])
      config = service.proxy_config[:data]
      assert_match(/server a\s+10\.0\.0\.5:8080 check/, config)
      assert_match(/server c\s+10\.0\.0\.6:8080 check/, config)
      refute_match(/server b/, config)
    end

    it 'never has a server line without an address' do
      service.stubs(:pod).returns([pod('a', nil)])
      refute_match(/^\s*server /, service.proxy_config[:data])
    end

    it 'is written to the file of the service' do
      service.stubs(:pod).returns([pod('a', '10.0.0.5')])
      assert_equal '0012_web.cfg', service.proxy_config[:filename]
    end
  end
end
