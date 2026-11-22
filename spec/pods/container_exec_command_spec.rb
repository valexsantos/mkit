# frozen_string_literal: true

require 'spec_helper'
require 'mkit/pods/container_exec_command'

describe MKIt::ContainerExecCommand do
  let(:containers) { mock('containers') }
  let(:ws) { FakeWs.new }
  let(:pod) { OpenStruct.new(name: 'p1') }

  def exec_command(options)
    described_class.new(pod, ws, options: options, containers: containers)
  end

  it 'bridges the exec stream to the websocket' do
    reader, writer = IO.pipe
    containers.expects(:attach_exec).with('p1', %w[ls -l], detached: false).returns(writer)
    cmd = exec_command(varargs: ['ls -l'])
    thread = cmd.register
    assert_respond_to ws.handler, :call
    writer.close
    thread.join(1)
    assert ws.closed?
    reader.close
  end

  it 'keeps the characters split between reads whole' do
    reader, writer = IO.pipe
    containers.stubs(:attach_exec).returns(reader)
    thread = exec_command(varargs: ['cat']).register
    bytes = 'ção'.b
    writer.write(bytes[0, 2])
    writer.flush
    sleep 0.05
    writer.write(bytes[2..])
    writer.close
    thread.join(1)
    assert_equal 'ção', ws.sent.join
    assert(ws.sent.all?(&:valid_encoding?))
  end

  it 'relays websocket messages to the exec stdin' do
    socket = StringIO.new
    containers.stubs(:attach_exec).returns(socket)
    exec_command(varargs: ['sh']).register
    ws.handler.call('ls')
    assert_equal 'ls', socket.string
  end

  it 'does not relay input when detached' do
    containers.expects(:attach_exec).with('p1', %w[sleep 1], detached: true).returns(StringIO.new)
    exec_command(varargs: ['sleep 1'], detached: 'true').register
    assert_nil ws.handler
  end

  it 'closes the stream on unregister' do
    socket = StringIO.new
    containers.stubs(:attach_exec).returns(socket)
    cmd = exec_command(varargs: ['sh'])
    cmd.register
    cmd.unregister
    assert socket.closed?
  end
end
