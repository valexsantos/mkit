# frozen_string_literal: true

require 'spec_helper'
require 'support/in_memory_db'
require 'support/logger'
require 'mkit/app/model/pod'
require 'mkit/app/model/mkit_job'
require 'mkit/app/model/dns_host'

ActiveRecord::Schema.define do
  create_table :pods, force: true do |t|
    t.string :name
    t.string :pod_id
    t.string :ip
    t.string :status
    t.integer :service_id
  end
end

ActiveRecord::Schema.define do
  create_table :dns_hosts, force: true do |t|
    t.integer :service_id
    t.integer :pod_id
    t.string :name
    t.string :ip
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
    let(:pod) { described_class.create!(name: 'web', ip: '10.0.0.5') }

    before do
      pod.stubs(:service).returns(OpenStruct.new(pods_network: 'mkit', id: 7, name: 'svc'))
      pod.stubs(:update_dns)
    end

    it 'keeps the ip and publishes nothing when it did not change' do
      MkitJob.expects(:publish).never
      pod.expects(:update_dns).never
      assert_equal '10.0.0.5', pod.sync_ip(info(running: true, addresses: { 'mkit' => '10.0.0.5' }))
    end

    it 'saves the new ip and its dns, then publishes pod_ip_updated' do
      sequence = sequence('ip update')
      pod.expects(:update_dns).in_sequence(sequence)
      MkitJob.expects(:publish).with(topic: :pod_ip_updated, service_id: 7, pod_id: pod.id).in_sequence(sequence)
      assert_equal '10.0.0.9', pod.sync_ip(info(running: true, addresses: { 'mkit' => '10.0.0.9' }))
      assert_equal '10.0.0.9', described_class.find(pod.id).ip # already persisted when the job is published
    end

    it 'sets the first ip of a new pod' do
      pod.update!(ip: nil)
      MkitJob.expects(:publish)
      assert_equal '10.0.0.5', pod.sync_ip(info(running: true, addresses: { 'mkit' => '10.0.0.5' }))
    end

    it 'keeps the last ip while the container exists without one (stopped or not started)' do
      MkitJob.expects(:publish).never
      assert_equal '10.0.0.5', pod.sync_ip(info(running: false, addresses: { 'mkit' => '' }))
      assert_equal '10.0.0.5', pod.sync_ip(info(running: false, addresses: { 'other' => '1.1.1.1' }))
      assert_equal '10.0.0.5', pod.ip
    end

    describe 'when the container no longer exists' do
      it 'clears the ip, drops the dns record and publishes pod_ip_updated' do
        DnsHost.create!(pod_id: pod.id, name: 'svc.internal', ip: '10.0.0.5')
        MkitJob.expects(:publish).with(topic: :pod_ip_updated, service_id: 7, pod_id: pod.id)
        assert_nil pod.sync_ip(nil)
        assert_nil described_class.find(pod.id).ip
        assert_equal 0, DnsHost.where(pod_id: pod.id).count
      end

      it 'publishes nothing when the pod had no ip already' do
        pod.update!(ip: nil)
        MkitJob.expects(:publish).never
        assert_nil pod.sync_ip(nil)
      end
    end

    it 'does not publish when notify is false, the caller does it' do
      MkitJob.expects(:publish).never
      pod.sync_ip(info(running: true, addresses: { 'mkit' => '10.0.0.9' }), notify: false)
      assert pod.saved_change_to_ip?
      assert_equal '10.0.0.9', described_class.find(pod.id).ip
    end

    it 'does not wait for the ip' do
      pod.expects(:sleep).never
      pod.sync_ip(info(running: false))
    end
  end
end
