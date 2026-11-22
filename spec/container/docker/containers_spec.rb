# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/docker/containers'
require 'mkit/container/http/unix_client'

describe MKIt::Container::Docker::Containers do
  let(:client) { mock('client') }
  let(:containers) { MKIt::Container::Docker::Containers.new(client) }

  def frame(payload, type = 1)
    [type, 0, 0, 0, payload.bytesize].pack('CCCCN') + payload
  end

  describe '#run' do
    let(:spec) { OpenStruct.new(name: 'p1', image: 'repo:5000/img', to_h: {}) }

    before { MKIt::Container::Docker::Payload.stubs(:new).returns(stub(to_h: {})) }

    it 'creates and starts the container' do
      client.expects(:post).with('/containers/create', {}, { name: 'p1' }).returns('Id' => 'abc')
      client.expects(:post).with('/containers/abc/start')
      assert_equal 'abc', containers.run(spec)
    end

    it 'pulls the image when create returns 404, then starts' do
      client.expects(:post).with('/containers/create', {}, { name: 'p1' }).twice.returns(nil).then.returns('Id' => 'abc')
      client.expects(:post).with('/images/create', nil, { fromImage: 'repo:5000/img', tag: 'latest' })
      client.expects(:post).with('/containers/abc/start')
      assert_equal 'abc', containers.run(spec)
    end

    it 'raises NotFound when the image cannot be pulled' do
      client.stubs(:post).with('/containers/create', {}, { name: 'p1' }).returns(nil)
      client.stubs(:post).with('/images/create', nil, instance_of(Hash))
      assert_raises(MKIt::Container::NotFound) { containers.run(spec) }
    end

    {
      'nginx' => ['nginx', 'latest'], 'nginx:1.2' => ['nginx', '1.2'], 'repo:5000/img' => ['repo:5000/img', 'latest'],
      'repo:5000/img:2' => ['repo:5000/img', '2'], 'img@sha256:abc' => ['img@sha256:abc', nil]
    }.each do |image, (from, tag)|
      it "splits image #{image}" do
        client.stubs(:post).with('/containers/create', {}, instance_of(Hash)).returns(nil).then.returns('Id' => 'x')
        client.expects(:post).with('/images/create', nil, { fromImage: from, tag: tag }.compact)
        client.stubs(:post).with('/containers/x/start')
        containers.run(OpenStruct.new(name: 'p', image: image))
      end
    end
  end

  it 'starts, stops and removes' do
    client.expects(:post).with('/containers/c/start')
    client.expects(:post).with('/containers/c/stop')
    client.expects(:delete).with('/containers/c', force: true)
    containers.start('c')
    containers.stop('c')
    containers.remove('c')
  end

  it 'finds a container as an Info, nil when missing' do
    client.stubs(:get).with('/containers/c/json')
          .returns('Id' => 'c', 'Name' => '/web', 'State' => { 'Running' => true })
    client.stubs(:get).with('/containers/zz/json').returns(nil)
    info = containers.find('c')
    assert_instance_of MKIt::Container::Info, info
    assert_equal %w[c web], [info.id, info.name]
    assert info.running?
    assert_nil containers.find('zz')
  end

  describe '#exec' do
    it 'runs the command and returns the output' do
      client.expects(:post).with('/containers/c/exec', has_entries('Cmd' => %w[ls -l], 'AttachStdin' => false))
            .returns('Id' => 'e1')
      client.expects(:post).with('/exec/e1/start', 'Detach' => false, 'Tty' => true).returns("out\n")
      client.expects(:get).with('/exec/e1/json').returns('ExitCode' => 0)
      assert_equal "out\n", containers.exec('c', 'ls -l')
    end

    it 'raises ExecFailed on a non zero exit code' do
      client.stubs(:post).returns({ 'Id' => 'e1' }, 'boom')
      client.stubs(:get).with('/exec/e1/json').returns('ExitCode' => 2)
      err = assert_raises(MKIt::Container::ExecFailed) { containers.exec('c', 'false') }
      assert_match(/exited with 2/, err.message)
    end
  end

  describe 'logs' do
    it 'returns demuxed logs' do
      client.stubs(:get).with('/containers/c/json').returns('Config' => { 'Tty' => false })
      client.expects(:get_raw).with('/containers/c/logs', { stdout: 1, stderr: 1, tail: 20 }).returns(frame('hi!'))
      assert_equal 'hi!', containers.logs('c')
    end

    it 'returns raw logs for tty containers' do
      client.stubs(:get).with('/containers/c/json').returns('Config' => { 'Tty' => true })
      client.stubs(:get_raw).returns('raw')
      assert_equal 'raw', containers.logs('c', tail: 5)
    end

    it 'returns an empty string when the container does not exist' do
      client.stubs(:get_raw).returns(nil)
      assert_equal '', containers.logs('c')
    end

    it 'follows logs demuxing the frames' do
      client.stubs(:get).with('/containers/c/json').returns('Config' => { 'Tty' => false })
      client.expects(:stream_chunks).with('/containers/c/logs', { stdout: 1, stderr: 1, tail: 3, follow: 1, timestamps: 1 })
            .multiple_yields([frame('a')], [frame('b')])
      got = []
      containers.follow_logs('c', tail: 3, follow: true, timestamps: true) { |t| got << t }
      assert_equal %w[a b], got
    end

    it 'follows tty logs without demuxing' do
      client.stubs(:get).with('/containers/c/json').returns('Config' => { 'Tty' => true })
      client.stubs(:stream_chunks).yields('plain')
      got = []
      containers.follow_logs('c') { |t| got << t }
      assert_equal ['plain'], got
    end

    it 'finds the log file' do
      client.stubs(:get).with('/containers/c/json').returns('LogPath' => '/var/log/c.log')
      client.stubs(:get).with('/containers/zz/json').returns(nil)
      assert_equal '/var/log/c.log', containers.log_path('c')
      assert_nil containers.log_path('zz')
    end
  end

  describe '#attach_exec' do
    it 'creates an interactive exec and hijacks its stream' do
      client.expects(:post).with('/containers/c/exec',
                                 has_entries('Cmd' => ['sh'], 'AttachStdin' => true, 'Tty' => true, 'Detach' => false))
            .returns('Id' => 'e1')
      client.expects(:hijack).with('/exec/e1/start', 'Detach' => false, 'Tty' => true).returns(:sock)
      assert_equal :sock, containers.attach_exec('c', ['sh'])
    end

    it 'does not attach anything when detached' do
      client.expects(:post).with('/containers/c/exec',
                                 has_entries('AttachStdin' => false, 'AttachStdout' => false, 'Detach' => true))
            .returns('Id' => 'e1')
      client.stubs(:hijack).returns(:sock)
      containers.attach_exec('c', ['sleep', '1'], detached: true)
    end
  end

  it 'talks to a real unix socket' do
    routes = { ['POST', '/containers/c/start'] => [204, ''], ['GET', '/containers/c/json'] => [200, '{"Id":"c"}'] }
    with_daemon(routes) do |sock, reqs|
      real = MKIt::Container::Docker::Containers.new(MKIt::Container::Http::UnixClient.new(socket: sock))
      real.start('c')
      assert_equal 'c', real.find('c').id
      assert_equal [%w[POST /containers/c/start], %w[GET /containers/c/json]], reqs.map { |r| r[0, 2] }
    end
  end
end
