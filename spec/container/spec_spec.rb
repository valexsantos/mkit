# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/spec'

describe MKIt::Container::Spec do
  def service(**attrs)
    OpenStruct.new({ image: 'nginx:1', command: 'sh -c "echo hi"', pods_network: 'mkit', my_dns: '10.0.0.1',
                     service_config: [OpenStruct.new(ctype: MKIt::CType::ENVIRONMENT.to_s, key: 'A', value: 'b c'),
                                     OpenStruct.new(ctype: 'other', key: 'X', value: 'y')],
                     volume: [OpenStruct.new(name: 'v', path: '/data')] }.merge(attrs))
  end

  let(:spec) { described_class.new(name: 'p1', service: service) }

  it 'exposes the runtime neutral description of the container' do
    assert_equal 'p1', spec.name
    assert_equal 'nginx:1', spec.image
    assert_equal ['A=b c'], spec.env
    assert_equal ['v:/data'], spec.binds
    assert_equal ['sh', '-c', 'echo hi'], spec.command
    assert_equal 'mkit', spec.network
    assert_equal '10.0.0.1', spec.dns
  end

  it 'tolerates a service without config, volumes or command' do
    s = described_class.new(name: 'p', service: service(service_config: nil, volume: nil, command: nil))
    assert_empty s.env
    assert_empty s.binds
    assert_empty s.command
  end

  it 'has no limits without resources' do
    assert_nil spec.cpu_millicores
    assert_nil spec.memory_mib
    assert_nil spec.memory_swap_mib
  end

  it 'reads limits expressed as <n>m' do
    res = OpenStruct.new(cpu_limits: '500m', memory_limits: '512m', memory_swap_limits: nil)
    s = described_class.new(name: 'p', service: service(resource: res))
    assert_equal 500, s.cpu_millicores
    assert_equal 512, s.memory_mib
    assert_nil s.memory_swap_mib
  end
end
