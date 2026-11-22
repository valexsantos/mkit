# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/info'
require 'mkit/container/event'

describe MKIt::Container::Info do
  it 'defaults to a stopped container without addresses' do
    info = described_class.new(id: 'a', name: 'n')
    refute info.running?
    refute info.tty?
    assert_empty info.addresses
  end

  it 'returns the ip in a network, nil when blank or unknown' do
    info = described_class.new(id: 'a', name: 'n', addresses: { 'mkit' => '10.0.0.2', 'none' => '' })
    assert_equal '10.0.0.2', info.ip_on('mkit')
    assert_nil info.ip_on('none')
    assert_nil info.ip_on('missing')
  end
end

describe MKIt::Container::Info, 'failure details' do
  it 'exposes exit code, oom and runtime error' do
    info = described_class.new(id: 'a', name: 'n', exit_code: 1, oom_killed: true, error: 'no such file')
    assert_equal 1, info.exit_code
    assert info.oom_killed?
    assert_equal 'no such file', info.error
  end

  it 'treats an empty error as none' do
    assert_nil described_class.new(id: 'a', name: 'n', error: '').error
  end
end

describe MKIt::Container::Event do
  it 'describes itself' do
    e = described_class.new(kind: :container, action: :start, container_id: 'abc', container_name: 'web')
    assert_equal '<container> <start> container=abc name=web', e.to_s
    assert_equal '<network> <connect> container=- name=-', described_class.new(kind: :network, action: :connect).to_s
    assert_match(/exit_code=2\z/, described_class.new(kind: :container, action: :die, exit_code: 2).to_s)
  end
end
