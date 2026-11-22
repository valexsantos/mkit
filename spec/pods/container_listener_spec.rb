# frozen_string_literal: true

require 'spec_helper'
require 'mkit/pods/container_listener'

# The pod model needs the whole application: a stand-in with the same finder is enough here.
class Pod; end unless defined?(Pod)

describe MKIt::ContainerListener do
  let(:containers) { mock('containers') }
  let(:events) { mock('events') }
  let(:api) { OpenStruct.new(containers: containers, events: events) }
  let(:service) { mock('service') }
  let(:pod) { stub('pod', service: service, name: 'web') }
  let(:listener) { described_class.new(api: api) }

  def event(kind, action, id: 'abc', name: 'web')
    MKIt::Container::Event.new(kind: kind, action: action, container_id: id, container_name: name)
  end

  def handle(event)
    listener.send(:parse_message, event)
  end

  describe 'container events' do
    before { Pod.stubs(:find_by).with(name: 'web').returns(pod) }

    it 'records the container id and status on create' do
      pod.expects(:pod_id=).with('abc')
      pod.expects(:status=).with(MKIt::Status::CREATED)
      pod.expects(:save)
      service.expects(:update_status!)
      handle(event(:container, :create))
    end

    it 'records the container id and syncs the ip on start' do
      info = MKIt::Container::Info.new(id: 'abc', name: 'web', running: true, addresses: { 'mkit' => '10.0.0.5' })
      containers.expects(:find).with('abc').returns(info)
      pod.expects(:pod_id=).with('abc')
      pod.expects(:sync_ip).with(info)
      pod.expects(:save)
      service.expects(:update_status!)
      handle(event(:container, :start))
    end

    %i[kill stop].each do |action|
      it "recomputes the service status on #{action}" do
        service.expects(:update_status!)
        handle(event(:container, action))
      end
    end

    describe 'die' do
      def die(code: 1)
        MKIt::Container::Event.new(kind: :container, action: :die, container_id: 'abc', container_name: 'web', exit_code: code)
      end

      def info(**attrs)
        MKIt::Container::Info.new(id: 'abc', name: 'web', **attrs)
      end

      before { service.stubs(:update_status!) }

      it 'recomputes the service status' do
        containers.stubs(:find).returns(nil)
        containers.stubs(:logs).returns('')
        service.expects(:update_status!)
        handle(die)
      end

      it 'logs the exit code with the last output of the container' do
        containers.stubs(:find).returns(info(exit_code: 1))
        containers.expects(:logs).with('web', tail: 20).returns("starting\nFATAL: bad config\n")
        MKItLogger.expects(:error).with(all_of(includes('pod web died with exit code 1'),
                                               includes('last output:'), includes('FATAL: bad config')))
        handle(die)
      end

      it 'logs the runtime error and the oom kill' do
        containers.stubs(:find).returns(info(exit_code: 137, oom_killed: true, error: 'cannot start'))
        containers.stubs(:logs).returns('')
        MKItLogger.expects(:error).with(all_of(includes('exit code 137'), includes('out of memory'),
                                               includes('runtime error: cannot start')))
        handle(die(code: 137))
      end

      it 'is a warning when ended by a signal (stop, kill)' do
        containers.stubs(:find).returns(info(exit_code: 143))
        containers.stubs(:logs).returns('')
        MKItLogger.expects(:warn).with(includes('exit code 143'))
        MKItLogger.expects(:error).never
        handle(die(code: 143))
      end

      it 'only informs on a clean exit' do
        containers.stubs(:find).returns(info(exit_code: 0))
        MKItLogger.expects(:error).never
        containers.expects(:logs).never
        handle(die(code: 0))
      end

      it 'uses the inspected exit code when the event has none' do
        containers.stubs(:find).returns(info(exit_code: 2))
        containers.stubs(:logs).returns('')
        MKItLogger.expects(:error).with(includes('exit code 2'))
        handle(die(code: nil))
      end

      it 'still reports when the container is gone or its output cannot be read' do
        containers.stubs(:find).returns(nil)
        containers.stubs(:logs).raises(MKIt::Container::Error, 'gone')
        MKItLogger.expects(:error).with(includes('pod web died with exit code 1'))
        handle(die)
      end
    end

    it 'logs an out of memory event' do
      MKItLogger.expects(:error).with(includes('pod web ran out of memory'))
      handle(event(:container, :oom))
    end

    it 'removes the pod from the proxy config when its container is destroyed' do
      pod.expects(:sync_ip).with(nil)
      pod.expects(:save)
      service.expects(:update_status!)
      handle(event(:container, :destroy))
    end

    it 'ignores other actions' do
      service.expects(:update_status!).never
      handle(event(:container, :rename))
    end

    it 'ignores containers that are not pods' do
      Pod.stubs(:find_by).with(name: 'other').returns(nil)
      service.expects(:update_status!).never
      handle(event(:container, :start, name: 'other'))
    end
  end

  describe 'network events' do
    let(:info) { MKIt::Container::Info.new(id: 'abc', name: 'web') }

    it 'syncs the pod ip when the container connects' do
      containers.expects(:find).with('abc').returns(info)
      Pod.stubs(:find_by).with(name: 'web').returns(pod)
      pod.expects(:sync_ip).with(info)
      pod.expects(:save)
      handle(event(:network, :connect, name: nil))
    end

    it 'does nothing on disconnect' do
      containers.stubs(:find).returns(info)
      Pod.stubs(:find_by).returns(pod)
      pod.expects(:sync_ip).never
      handle(event(:network, :disconnect, name: nil))
    end

    it 'ignores network events without a container (create, destroy) without calling the runtime' do
      containers.expects(:find).never
      %i[create destroy].each { |action| handle(event(:network, action, id: nil, name: nil)) }
    end

    it 'ignores containers that no longer exist' do
      containers.expects(:find).with('abc').returns(nil)
      Pod.expects(:find_by).never
      handle(event(:network, :connect, name: nil))
    end

    it 'ignores containers that are not pods' do
      containers.stubs(:find).returns(info)
      Pod.stubs(:find_by).returns(nil)
      pod.expects(:sync_ip).never
      handle(event(:network, :connect, name: nil))
    end
  end

  it 'ignores other kinds of event' do
    Pod.expects(:find_by).never
    handle(event(:image, :pull, id: nil, name: nil))
  end

  describe 'event stream' do
    it 'enqueues the events and reconnects when the stream ends' do
      e = event(:container, :start)
      events.stubs(:each).yields(e).then.raises(MKIt::Container::Error, 'gone')
      described_class.send(:remove_const, :RECONNECT_DELAY)
      described_class.const_set(:RECONNECT_DELAY, 0)
      thread = Thread.new { listener.send(:listen) }
      queue = listener.instance_variable_get(:@queue)
      Timeout.timeout(2) { assert_same e, queue.pop }
      thread.kill
    end
  end
end
