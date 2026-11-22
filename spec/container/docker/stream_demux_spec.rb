# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/docker/stream_demux'

describe MKIt::Container::Docker::StreamDemux do
  def frame(type, payload)
    [type, 0, 0, 0, payload.bytesize].pack('CCCCN') + payload
  end

  it 'demultiplexes frames split across chunks' do
    data = frame(1, "hello\n") + frame(2, 'err')
    out = []
    d = described_class.new
    data.each_char.each_slice(5) { |c| d.feed(c.join) { |p| out << p } }
    assert_equal ["hello\n", 'err'], out
  end

  it 'decodes a whole buffer' do
    assert_equal 'ab', described_class.decode(frame(1, 'a') + frame(1, 'b'))
  end

  it 'keeps an incomplete frame until the rest arrives' do
    d = described_class.new
    out = []
    data = frame(1, 'hello')
    d.feed(data[0, 10]) { |p| out << p }
    assert_empty out
    d.feed(data[10..]) { |p| out << p }
    assert_equal ['hello'], out
  end

  it 'keeps a character split between two frames of the same stream whole' do
    bytes = 'ã'.b
    out = []
    described_class.new.tap do |d|
      d.feed(frame(1, bytes[0]) + frame(1, bytes[1])) { |t| out << t }
    end
    assert_equal ['ã'], out
  end

  it 'does not mix the pending bytes of stdout and stderr' do
    out = []
    d = described_class.new
    d.feed(frame(1, 'ã'.b[0]) + frame(2, 'x') + frame(1, 'ã'.b[1])) { |t| out << t }
    assert_equal %w[x ã], out
  end

  it 'yields what was held back when the stream ends' do
    out = []
    d = described_class.new
    d.feed(frame(1, 'ã'.b[0])) { |t| out << t }
    assert_empty out
    d.flush { |t| out << t }
    assert_equal ["\uFFFD"], out
  end

  it 'decodes utf-8 payloads' do
    assert_equal 'olá', described_class.decode(frame(1, 'olá'))
  end
end
