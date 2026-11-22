# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/http/unix_client'

describe MKIt::Container::Http::UnixClient do
  it 'gets json and maps 404 to nil' do
    with_daemon({ ['GET', '/containers/a/json'] => [200, '{"State":{"Running":true}}'] }) do |sock, _|
      c = described_class.new(socket: sock)
      assert_equal true, c.get('/containers/a/json')['State']['Running']
      assert_nil c.get('/containers/zzz/json')
    end
  end

  it 'posts a json body and raises Container::Error with the status on failures' do
    with_daemon({ ['POST', '/networks/create'] => [201, '{"Id":"n1"}'],
                  ['POST', '/boom'] => [500, '{"message":"bad"}'] }) do |sock, reqs|
      c = described_class.new(socket: sock)
      assert_equal 'n1', c.post('/networks/create', 'Name' => 'x')['Id']
      assert_equal '{"Name":"x"}', reqs.first[2]
      err = assert_raises(MKIt::Container::Error) { c.post('/boom') }
      assert_equal 500, err.status
      assert_equal 'bad', err.message
    end
  end

  it 'sends the query string' do
    with_daemon({ ['DELETE', '/containers/a'] => [204, ''] }) do |sock, reqs|
      described_class.new(socket: sock).delete('/containers/a', force: true)
      assert_equal '/containers/a?force=true', reqs.first[1]
    end
  end

  it 'returns the raw body, nil when not found' do
    with_daemon({ ['GET', '/logs'] => [200, 'plain text'] }) do |sock, _|
      c = described_class.new(socket: sock)
      assert_equal 'plain text', c.get_raw('/logs')
      assert_nil c.get_raw('/missing')
    end
  end

  it 'returns the body as is when it is not json' do
    with_daemon({ ['GET', '/text'] => [200, 'not json'] }) do |sock, _|
      assert_equal 'not json', described_class.new(socket: sock).get('/text')
    end
  end

  it 'posts and returns the raw body without parsing it' do
    with_daemon({ ['POST', '/exec/e/start'] => [200, "1\n"] }) do |sock, reqs|
      assert_equal "1\n", described_class.new(socket: sock).post_raw('/exec/e/start', { 'Detach' => false })
      assert_equal '{"Detach":false}', reqs.first[2]
    end
  end

  it 'post_raw returns nil when not found and raises on errors' do
    with_daemon({ ['POST', '/boom'] => [500, '{"message":"bad"}'] }) do |sock, _|
      c = described_class.new(socket: sock)
      assert_nil c.post_raw('/missing')
      assert_raises(MKIt::Container::Error) { c.post_raw('/boom') }
    end
  end

  it 'raises Container::Error on read timeouts' do
    Net::HTTP.any_instance.stubs(:request).raises(Net::ReadTimeout)
    err = assert_raises(MKIt::Container::Error) { described_class.new(socket: '/x.sock').get('/slow') }
    assert_match(/timeout/, err.message)
  end

  it 'streams newline delimited json split across chunks' do
    ev = %({"Type":"container","Action":"start"}\n{"Type":"network","Action":"connect"}\n)
    with_daemon({ ['GET', '/events'] => [200, ev] }) do |sock, _|
      got = []
      described_class.new(socket: sock).stream('/events') { |e| got << e['Type'] }
      assert_equal %w[container network], got
    end
  end

  it 'raises Container::Error when the stream request fails' do
    with_daemon({}) do |sock, _|
      assert_raises(MKIt::Container::Error) { described_class.new(socket: sock).stream('/events') {} }
    end
  end

  it 'raises Container::Error when the socket cannot be reached' do
    err = assert_raises(MKIt::Container::Error) { described_class.new(socket: '/nonexistent.sock').get('/x') }
    assert_match(/cannot reach socket/, err.message)
    assert_raises(MKIt::Container::Error) { described_class.new(socket: '/nonexistent.sock').hijack('/x', {}) }
  end
end
