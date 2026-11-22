# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/spec'
require 'mkit/container/docker/payload'

describe MKIt::Container::Docker::Payload do
  def payload(resource: nil, command: 'sh -c "echo hi"')
    svc = OpenStruct.new(
      image: 'nginx:1', command: command, pods_network: 'mkit', my_dns: '10.0.0.1', resource: resource,
      service_config: [OpenStruct.new(ctype: MKIt::CType::ENVIRONMENT.to_s, key: 'A', value: 'b c')],
      volume: [OpenStruct.new(name: 'v', path: '/data')]
    )
    described_class.new(MKIt::Container::Spec.new(name: 'p1', service: svc)).to_h
  end

  it 'builds the container payload' do
    h = payload
    assert_equal 'nginx:1', h['Image']
    assert_equal ['A=b c'], h['Env']
    assert_equal ['sh', '-c', 'echo hi'], h['Cmd']
    assert_equal ['v:/data'], h['HostConfig']['Binds']
    assert_equal 'mkit', h['HostConfig']['NetworkMode']
    assert_equal ['10.0.0.1'], h['HostConfig']['Dns']
  end

  it 'omits Cmd when the service has no command' do
    refute payload(command: '').key?('Cmd')
  end

  it 'maps resource limits to NanoCpus and bytes' do
    hc = payload(resource: OpenStruct.new(cpu_limits: '500m', memory_limits: '512m',
                                          memory_swap_limits: '1024m'))['HostConfig']
    assert_equal 500_000_000, hc['NanoCpus']
    assert_equal 512 * 1024 * 1024, hc['Memory']
    assert_equal 1024 * 1024 * 1024, hc['MemorySwap']
  end

  it 'sends no limits when none are set' do
    hc = payload['HostConfig']
    %w[NanoCpus Memory MemorySwap].each { |k| refute hc.key?(k) }
  end
end
