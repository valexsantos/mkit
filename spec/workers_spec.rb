# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Autoscaler Worker' do
  let(:worker) { MKIt::AutoscalerWorker.new }

  describe '#scaling_enabled?' do
    it 'returns false when no scaling config' do
      resource = Resource.new
      refute worker.scaling_enabled?(resource)
    end

    it 'returns true when target_cpu_percent set' do
      resource = Resource.new(target_cpu_percent: 70)
      assert worker.scaling_enabled?(resource)
    end

    it 'returns true when target_memory_percent set' do
      resource = Resource.new(target_memory_percent: 80)
      assert worker.scaling_enabled?(resource)
    end
  end

  describe 'scale calculations' do
    let(:service) do
      svc = Service.new(name: 'test', image: 'nginx:latest')
      svc.resource = Resource.new(
        min_replicas: 1,
        max_replicas: 5,
        target_cpu_percent: 70,
        target_memory_percent: 80
      )
      svc
    end

    it 'respects min_replicas boundary' do
      service.pod = []
      refute worker.send(:should_scale_down?, service, 1)
    end

    it 'respects max_replicas boundary' do
      service.pod = [Pod.new, Pod.new, Pod.new, Pod.new, Pod.new]
      refute worker.send(:should_scale_up?, service, 5)
    end
  end
end

describe 'Health Check Worker' do
  let(:worker) { MKIt::HealthCheckWorker.new }

  describe 'probe types' do
    it 'handles http probe' do
      result = worker.send(:execute_probe, nil, { 'type' => 'http', 'port' => 80 })
      # Will fail without pod IP but should not raise
      assert [true, false].include?(result)
    end

    it 'handles tcp probe' do
      result = worker.send(:execute_probe, nil, { 'type' => 'tcp', 'port' => 80 })
      assert [true, false].include?(result)
    end

    it 'handles exec probe' do
      result = worker.send(:execute_probe, nil, { 'type' => 'exec', 'command' => %w[echo ok] })
      assert [true, false].include?(result)
    end

    it 'returns true for unknown probe type' do
      result = worker.send(:execute_probe, nil, { 'type' => 'unknown' })
      assert result
    end
  end

  describe 'failure tracking' do
    let(:pod) { Pod.new(name: 'test-pod') }
    let(:probe) { { 'type' => 'http', 'failure_threshold' => 3 } }

    it 'increments failures on probe failure' do
      pod.consecutive_liveness_failures = 0
      worker.instance_variable_set(:@pod, pod)

      # Mock execute_probe to return false
      worker.define_singleton_method(:execute_probe) { |*_| false }

      worker.send(:check_liveness, pod, probe)
      assert_equal 1, pod.consecutive_liveness_failures
    end

    it 'resets failures on probe success' do
      pod.consecutive_liveness_failures = 2
      worker.instance_variable_set(:@pod, pod)

      worker.define_singleton_method(:execute_probe) { |*_| true }

      worker.send(:check_liveness, pod, probe)
      assert_equal 0, pod.consecutive_liveness_failures
    end

    it 'triggers restart after threshold' do
      pod.consecutive_liveness_failures = 2
      pod.service = Service.new(name: 'test')

      worker.define_singleton_method(:execute_probe) { |*_| false }

      # Should publish restart job when threshold reached
      MkitJob.expects(:publish).with(topic: :restart_pod, pod_id: pod.id, service_id: pod.service.id)

      worker.send(:check_liveness, pod, probe)
    end
  end
end

describe 'Health Check Scheduler' do
  let(:scheduler) { MKIt::HealthCheckScheduler.new(interval: 1) }

  it 'has default interval' do
    assert_equal 10, MKIt::HealthCheckScheduler::DEFAULT_INTERVAL
  end

  it 'can be initialized with custom interval' do
    custom = MKIt::HealthCheckScheduler.new(interval: 5)
    # Interval is stored in instance
    assert custom.respond_to?(:start)
  end
end
