# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/utf8_buffer'

describe MKIt::Container::Utf8Buffer do
  let(:buffer) { described_class.new }

  def chunks(text, size)
    text.b.chars.each_slice(size).map(&:join)
  end

  def decode(parts)
    parts.map { |part| buffer.feed(part) }.join + buffer.flush
  end

  it 'passes ascii through' do
    assert_equal 'hello', buffer.feed('hello')
    assert_equal '', buffer.flush
  end

  it 'keeps the characters whole whatever the chunk size' do
    text = "olá ção ─ ✓ 日本語 😀 fim\n"
    (1..9).each do |size|
      assert_equal text, decode(chunks(text, size)), "chunk size #{size}"
    end
  end

  it 'holds back an incomplete character until the rest arrives' do
    bytes = 'ã'.b # 2 bytes
    assert_equal '', buffer.feed(bytes[0])
    assert_equal 'ã', buffer.feed(bytes[1])
  end

  it 'holds back at most the incomplete tail of a 4 byte character' do
    bytes = '😀'.b
    assert_equal 'a', buffer.feed('a'.b + bytes[0, 3])
    assert_equal '😀', buffer.feed(bytes[3])
  end

  it 'does not hold back complete characters' do
    assert_equal 'é😀', buffer.feed('é😀'.b)
  end

  it 'turns an incomplete character at the end of the stream into the replacement character' do
    assert_equal '', buffer.feed('ã'.b[0])
    assert_equal "�", buffer.flush
    assert_equal '', buffer.flush
  end

  it 'replaces invalid bytes instead of raising' do
    assert_equal "a�b", buffer.feed("a\xFFb".b)
  end

  it 'returns utf-8 strings' do
    assert_equal Encoding::UTF_8, buffer.feed('x').encoding
    assert_equal Encoding::UTF_8, buffer.flush.encoding
  end

  it 'decodes a whole buffer' do
    assert_equal 'ção', described_class.decode('ção'.b)
  end
end
