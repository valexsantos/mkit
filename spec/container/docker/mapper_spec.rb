# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/docker/mapper'

describe MKIt::Container::Docker::Mapper do
  describe '.info' do
    let(:payload) do
      { 'Id' => 'abc123', 'Name' => '/web', 'State' => { 'Running' => true },
        'Config' => { 'Tty' => true },
        'NetworkSettings' => { 'Networks' => { 'mkit' => { 'IPAddress' => '10.0.0.5' },
                                               'bridge' => { 'IPAddress' => '' } } } }
    end

    it 'maps the container properties' do
      info = described_class.info(payload)
      assert_equal 'abc123', info.id
      assert_equal 'web', info.name
      assert info.running?
      assert info.tty?
      assert_equal '10.0.0.5', info.ip_on('mkit')
    end

    it 'maps a stopped container without networks' do
      info = described_class.info('Id' => 'x', 'Name' => '/db', 'State' => { 'Running' => false },
                                  'NetworkSettings' => { 'Networks' => {} })
      refute info.running?
      refute info.tty?
      assert_empty info.addresses
      assert_nil info.ip_on('mkit')
    end

    it 'tolerates a payload without state, config and network settings' do
      info = described_class.info('Id' => 'x', 'Name' => 'no-slash')
      assert_equal 'no-slash', info.name
      refute info.running?
      assert_empty info.addresses
    end

    it 'maps why the container ended' do
      info = described_class.info(payload.merge(
        'State' => { 'Running' => false, 'ExitCode' => 137, 'OOMKilled' => true, 'Error' => 'boom' }
      ))
      assert_equal 137, info.exit_code
      assert info.oom_killed?
      assert_equal 'boom', info.error
    end

    it 'has no error or oom by default' do
      info = described_class.info(payload.merge('State' => { 'Running' => true, 'ExitCode' => 0, 'Error' => '' }))
      assert_equal 0, info.exit_code
      refute info.oom_killed?
      assert_nil info.error
    end

    it 'has no ip while the runtime has not assigned one' do
      assert_nil described_class.info(payload).ip_on('bridge')
      assert_nil described_class.info(payload).ip_on('other')
    end
  end

  describe '.event' do
    def container_event(action, extra = {})
      { 'Type' => 'container', 'Action' => action, 'id' => 'abc',
        'Actor' => { 'ID' => 'abc', 'Attributes' => { 'name' => 'web', 'image' => 'nginx' } } }.merge(extra)
    end

    %w[create start kill die stop].each do |action|
      it "maps container #{action}" do
        e = described_class.event(container_event(action))
        assert_equal [:container, action.to_sym, 'abc', 'web'], [e.kind, e.action, e.container_id, e.container_name]
      end
    end

    it 'maps the exit code of a die event' do
      payload = container_event('die')
      payload['Actor']['Attributes']['exitCode'] = '137'
      assert_equal 137, described_class.event(payload).exit_code
      assert_nil described_class.event(container_event('start')).exit_code
    end

    it 'maps a network event to the container in its attributes' do
      e = described_class.event('Type' => 'network', 'Action' => 'connect',
                                'Actor' => { 'ID' => 'netid', 'Attributes' => { 'container' => 'abc', 'name' => 'mkit' } })
      assert_equal [:network, :connect, 'abc', nil], [e.kind, e.action, e.container_id, e.container_name]
    end

    it 'drops the arguments of the action' do
      assert_equal :exec_start, described_class.event(container_event('exec_start: ls -l')).action
    end

    it 'falls back to the actor id when the event has no id' do
      payload = container_event('start')
      payload.delete('id')
      assert_equal 'abc', described_class.event(payload).container_id
    end

    it 'keeps other kinds of event, without a container' do
      e = described_class.event('Type' => 'image', 'Action' => 'pull', 'Actor' => { 'ID' => 'nginx' })
      assert_equal [:image, :pull, nil, nil], [e.kind, e.action, e.container_id, e.container_name]
    end

    it 'tolerates an event without actor' do
      e = described_class.event('Type' => 'container', 'Action' => 'start')
      assert_nil e.container_name
    end
  end
end
