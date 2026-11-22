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

  it 'decodes utf-8 payloads' do
    assert_equal 'olá', described_class.decode(frame(1, 'olá'))
  end
end
