# frozen_string_literal: true

require 'spec_helper'
require 'mkit/sagas/asaga'
require 'mkit/container/registry'

# minimal collaborators, the real ones need the whole application
module MKIt
  module System
    def self.[](_name)
      @job_manager ||= Object.new.tap { |o| o.define_singleton_method(:register_worker) { |*_| } }
    end
  end
end
class Pod; end unless defined?(Pod)
require 'mkit/sagas/create_pod_saga'
require 'mkit/sagas/destroy_pod_saga'

describe 'pod sagas' do
  let(:containers) { mock('containers') }
  let(:job) { OpenStruct.new(topic: 'x', data: { 'pod_name' => 'p1' }) }

  describe MKIt::CreatePodSaga do
    it 'listens to create_pod_saga' do
      assert_equal ['create_pod_saga'], described_class.new(containers: containers).topics
    end

    it 'runs the pod container spec' do
      spec = OpenStruct.new(to_h: {})
      Pod.stubs(:find_by_name).with('p1').returns(stub(container_spec: spec))
      containers.expects(:run).with(spec)
      described_class.new(containers: containers).do_the(job)
    end
  end

  describe MKIt::DestroyPodSaga do
    it 'listens to destroy_pod_saga' do
      assert_equal ['destroy_pod_saga'], described_class.new(containers: containers).topics
    end

    it 'removes the container' do
      containers.expects(:remove).with('p1')
      described_class.new(containers: containers).do_the(job)
    end

    it 'swallows runtime errors so the pod can be destroyed anyway' do
      containers.stubs(:remove).raises(MKIt::Container::Error, 'gone')
      described_class.new(containers: containers).do_the(job)
    end
  end
end
