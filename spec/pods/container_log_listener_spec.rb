# frozen_string_literal: true

require 'spec_helper'
require 'mkit/pods/container_log_listener'

describe MKIt::ContainerLogListener do
  let(:containers) { mock('containers') }
  let(:ws) { FakeWs.new }
  let(:pod) { OpenStruct.new(name: 'p1') }

  def listener(options = {})
    described_class.new(pod, ws, options: options, containers: containers)
  end

  it 'sends complete lines and the unfinished remainder at the end' do
    containers.expects(:follow_logs).with('p1', has_entries(tail: 10)).multiple_yields(["one\ntw"], ["o\nthree"])
    listener.register.join
    assert_equal %w[one two three], ws.sent
    assert ws.closed?
  end

  it 'maps the options to the log query' do
    containers.expects(:follow_logs)
              .with('p1', tail: 5, follow: true, timestamps: true, details: false, since: '1h', until_: nil)
    listener(nr_lines: 5, follow: 'true', timestamps: 'true', since: '1h').register.join
  end

  it 'closes the websocket when the stream fails' do
    containers.stubs(:follow_logs).raises(MKIt::Container::Error, 'gone')
    listener.register.join
    assert ws.closed?
  end

  describe 'clear option' do
    it 'truncates the log file' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'p1.log')
        File.write(path, 'old')
        containers.expects(:log_path).with('p1').returns(path)
        listener(clear: true)
        assert_equal '', File.read(path)
      end
    end

    it 'does nothing when the log driver has no file' do
      containers.expects(:log_path).with('p1').returns(nil)
      listener(clear: true)
    end

    it 'is not applied by default' do
      containers.expects(:log_path).never
      listener
    end
  end
end
