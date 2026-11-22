# frozen_string_literal: true

require 'spec_helper'
require 'support/logger'
require 'mkit/pods/pod_reconciler'

# The models need the whole application: stand-ins with the used interface are enough here.
class Pod; end unless defined?(Pod)
class MkitJob; end unless defined?(MkitJob)

describe MKIt::PodReconciler do
  let(:containers) { mock('containers') }
  let(:reconciler) { described_class.new(containers: containers) }

  def service(id)
    stub("service #{id}", id: id, update_status!: true)
  end

  def pod(name, service, pod_id: 'old', ip_changed: false)
    stub(name.to_s, name: name, service: service, pod_id: pod_id, sync_ip: nil, saved_change_to_ip?: ip_changed,
                    update!: true)
  end

  def info(id = 'abc')
    MKIt::Container::Info.new(id: id, name: 'x')
  end

  before { MkitJob.stubs(:publish) }

  it 'syncs the ip of every pod from its container without notifying one by one' do
    svc = service(1)
    a = pod('a', svc)
    ia = info
    Pod.stubs(:all).returns([a])
    containers.expects(:find).with('a').returns(ia)
    a.expects(:sync_ip).with(ia, notify: false)
    reconciler.call
  end

  it 'syncs pods whose container no longer exists' do
    svc = service(1)
    gone = pod('gone', svc, ip_changed: true)
    Pod.stubs(:all).returns([gone])
    containers.stubs(:find).returns(nil)
    gone.expects(:sync_ip).with(nil, notify: false)
    reconciler.call
  end

  it 'publishes a single update_proxy_config per service whose ips changed' do
    svc = service(1)
    Pod.stubs(:all).returns([pod('a', svc, ip_changed: true), pod('b', svc, ip_changed: true)])
    containers.stubs(:find).returns(info)
    MkitJob.expects(:publish).with(topic: :update_proxy_config, service_id: 1).once
    assert_equal [svc], reconciler.call
  end

  it 'does not touch the proxy of services whose ips did not change' do
    svc = service(1)
    Pod.stubs(:all).returns([pod('a', svc)])
    containers.stubs(:find).returns(info)
    MkitJob.expects(:publish).never
    svc.expects(:update_status!).never
    assert_empty reconciler.call
  end

  it 'refreshes the status of the services it changed' do
    changed = service(1)
    changed.expects(:update_status!)
    Pod.stubs(:all).returns([pod('a', changed, ip_changed: true), pod('b', service(2))])
    containers.stubs(:find).returns(info)
    reconciler.call
  end

  it 'records the container id of the pod' do
    p1 = pod('a', service(1), pod_id: 'old')
    p1.expects(:update!).with(pod_id: 'new')
    Pod.stubs(:all).returns([p1])
    containers.stubs(:find).returns(info('new'))
    reconciler.call
  end

  it 'keeps the container id when it is the same or the container is gone' do
    same = pod('a', service(1), pod_id: 'abc')
    gone = pod('b', service(2))
    same.expects(:update!).never
    gone.expects(:update!).never
    Pod.stubs(:all).returns([same, gone])
    containers.stubs(:find).with('a').returns(info('abc'))
    containers.stubs(:find).with('b').returns(nil)
    reconciler.call
  end

  it 'skips pods without a service' do
    orphan = pod('orphan', nil)
    orphan.expects(:sync_ip).never
    Pod.stubs(:all).returns([orphan])
    containers.expects(:find).never
    reconciler.call
  end

  it 'keeps going when the runtime fails for a pod' do
    svc = service(1)
    broken = pod('broken', svc)
    fine = pod('fine', svc, ip_changed: true)
    Pod.stubs(:all).returns([broken, fine])
    containers.stubs(:find).with('broken').raises(MKIt::Container::Error, 'runtime down')
    containers.stubs(:find).with('fine').returns(info)
    MkitJob.expects(:publish).with(topic: :update_proxy_config, service_id: 1)
    reconciler.call
  end
end
