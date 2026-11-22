# frozen_string_literal: true

require 'spec_helper'
require 'support/in_memory_db'
require 'support/logger'
require 'mkit/app/model/pod'
require 'mkit/app/model/mkit_job'
require 'mkit/app/model/dns_host'
require 'mkit/pods/pod_reconciler'

ActiveRecord::Schema.define do
  create_table :pods, force: true do |t|
    t.string :name
    t.string :pod_id
    t.string :ip
    t.string :status
    t.integer :service_id
  end
  create_table :dns_hosts, force: true do |t|
    t.integer :service_id
    t.integer :pod_id
    t.string :name
    t.string :ip
  end
end

# the reconciler against real pod records
describe MKIt::PodReconciler do
  let(:containers) { mock('containers') }
  let(:service) { stub('service', id: 1, name: 'svc', pods_network: 'mkit', update_status!: true) }

  def info(name, id, ip)
    MKIt::Container::Info.new(id: id, name: name, running: true, addresses: { 'mkit' => ip })
  end

  before do
    Pod.delete_all
    DnsHost.delete_all
    Pod.any_instance.stubs(:service).returns(service)
    Pod.any_instance.stubs(:update_dns)
  end

  it 'updates ips and container ids, clears the pods without container and refreshes the proxy once' do
    Pod.create!(name: 'moved', ip: '10.0.0.5', pod_id: 'old')
    Pod.create!(name: 'same', ip: '10.0.0.6', pod_id: 'same-id')
    Pod.create!(name: 'gone', ip: '10.0.0.7')
    Pod.create!(name: 'fresh')
    containers.stubs(:find).with('moved').returns(info('moved', 'new-id', '10.0.0.9'))
    containers.stubs(:find).with('same').returns(info('same', 'same-id', '10.0.0.6'))
    containers.stubs(:find).with('gone').returns(nil)
    containers.stubs(:find).with('fresh').returns(info('fresh', 'fresh-id', '10.0.0.8'))
    MkitJob.expects(:publish).with(topic: :update_proxy_config, service_id: 1).once

    described_class.new(containers: containers).call

    ips = Pod.order(:name).pluck(:name, :ip, :pod_id)
    assert_equal [['fresh', '10.0.0.8', 'fresh-id'], ['gone', nil, nil], ['moved', '10.0.0.9', 'new-id'],
                  ['same', '10.0.0.6', 'same-id']], ips
  end

  it 'does nothing when everything is in sync' do
    Pod.create!(name: 'same', ip: '10.0.0.6', pod_id: 'same-id')
    containers.stubs(:find).returns(info('same', 'same-id', '10.0.0.6'))
    MkitJob.expects(:publish).never
    assert_empty described_class.new(containers: containers).call
  end

  it 'keeps the last ip of a stopped pod' do
    Pod.create!(name: 'stopped', ip: '10.0.0.6', pod_id: 's')
    containers.stubs(:find).returns(MKIt::Container::Info.new(id: 's', name: 'stopped', running: false,
                                                              addresses: { 'mkit' => '' }))
    MkitJob.expects(:publish).never
    described_class.new(containers: containers).call
    assert_equal '10.0.0.6', Pod.find_by(name: 'stopped').ip
  end
end
