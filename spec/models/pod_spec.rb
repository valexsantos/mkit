# frozen_string_literal: true

require 'spec_helper'
require 'support/in_memory_db'
require 'support/logger'
require 'mkit/app/model/pod'
require 'mkit/app/model/mkit_job'

ActiveRecord::Schema.define do
  create_table :pods, force: true do |t|
    t.string :name
    t.string :pod_id
    t.string :ip
    t.string :status
    t.integer :service_id
  end
end

describe Pod do
  let(:containers) { mock('containers') }
  let(:pod) { described_class.new(name: 'web', ip: '10.0.0.5') }

  before { MKIt::Container::Registry.stubs(:api).returns(OpenStruct.new(containers: containers)) }

  def info(running:, addresses: {})
    MKIt::Container::Info.new(id: 'abc', name: 'web', running: running, addresses: addresses)
  end

  describe '#set_status_from_container' do
    it 'is PENDING when the container does not exist' do
      containers.stubs(:find).with('web').returns(nil)
      assert_equal MKIt::Status::PENDING, pod.set_status_from_container
    end

    it 'is RUNNING when the container runs' do
      containers.stubs(:find).returns(info(running: true))
      assert_equal MKIt::Status::RUNNING, pod.set_status_from_container
    end

    it 'is STOPPED when the container exists but is not running' do
      containers.stubs(:find).returns(info(running: false))
      assert_equal MKIt::Status::STOPPED, pod.set_status_from_container
    end

    it 'persists the status' do
      containers.stubs(:find).returns(info(running: true))
      pod.set_status_from_container
      assert_equal MKIt::Status::RUNNING, described_class.find(pod.id).status
    end
  end

  describe '#start' do
    it 'starts a stopped container' do
      containers.stubs(:find).returns(info(running: false))
      containers.expects(:start).with('web')
      pod.start
    end

    it 'does not start a running container' do
      containers.stubs(:find).returns(info(running: true))
      containers.expects(:start).never
      pod.start
    end

    it 'tries to start when the container does not exist yet' do
      containers.stubs(:find).returns(nil)
      containers.expects(:start).with('web')
      pod.start
    end
  end

  describe '#stop' do
    it 'stops a running container' do
      containers.stubs(:find).returns(info(running: true))
      containers.expects(:stop).with('web')
      pod.stop
    end

    it 'does nothing when the container is stopped or missing' do
      containers.stubs(:find).returns(info(running: false)).then.returns(nil)
      containers.expects(:stop).never
      pod.stop
      pod.stop
    end
  end

  describe '#sync_ip' do
    before do
      pod.stubs(:service).returns(OpenStruct.new(pods_network: 'mkit', id: 7))
      pod.stubs(:update_dns)
    end

    it 'keeps the ip and publishes nothing when it did not change' do
      MkitJob.expects(:publish).never
      pod.expects(:update_dns).never
      assert_equal '10.0.0.5', pod.sync_ip(info(running: true, addresses: { 'mkit' => '10.0.0.5' }))
    end

    it 'updates the ip, the dns and publishes pod_ip_updated when it changed' do
      pod.expects(:update_dns)
      MkitJob.expects(:publish).with(topic: :pod_ip_updated, service_id: 7, pod_id: pod.id)
      assert_equal '10.0.0.9', pod.sync_ip(info(running: true, addresses: { 'mkit' => '10.0.0.9' }))
      assert_equal '10.0.0.9', pod.ip
    end

    it 'sets the first ip of a new pod' do
      pod.ip = nil
      MkitJob.expects(:publish)
      assert_equal '10.0.0.5', pod.sync_ip(info(running: true, addresses: { 'mkit' => '10.0.0.5' }))
    end

    it 'leaves the ip untouched when the container has none yet' do
      MkitJob.expects(:publish).never
      assert_equal '10.0.0.5', pod.sync_ip(info(running: false, addresses: { 'mkit' => '' }))
      assert_equal '10.0.0.5', pod.sync_ip(info(running: false, addresses: { 'other' => '1.1.1.1' }))
      assert_equal '10.0.0.5', pod.sync_ip(nil)
      assert_equal '10.0.0.5', pod.ip
    end

    it 'does not wait for the ip' do
      pod.expects(:sleep).never
      pod.sync_ip(info(running: false))
    end
  end
end
