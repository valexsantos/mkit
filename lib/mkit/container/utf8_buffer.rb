# frozen_string_literal: true

module MKIt
  module Container
    # Turns a stream of byte chunks into UTF-8 text without breaking characters.
    #
    # A multibyte character split between two chunks (socket reads, log frames) would otherwise
    # be invalid in both halves. The incomplete tail of a chunk is held back until the rest arrives.
    class Utf8Buffer
      MAX_SEQUENCE = 4

      def self.decode(data)
        buffer = new
        buffer.feed(data) + buffer.flush
      end

      def initialize
        @pending = String.new(encoding: Encoding::BINARY)
      end

      # text of the chunk (plus what was held back), without a trailing incomplete character
      def feed(chunk)
        data = @pending + chunk.b
        held = incomplete_tail(data)
        @pending = data.byteslice(data.bytesize - held, held)
        text(data.byteslice(0, data.bytesize - held))
      end

      # what is left when the stream ends (an incomplete character becomes the replacement character)
      def flush
        rest = @pending
        @pending = String.new(encoding: Encoding::BINARY)
        text(rest)
      end

      private

      def text(bytes)
        bytes.force_encoding(Encoding::UTF_8).scrub
      end

      # number of bytes at the end that start a character that is not complete yet
      def incomplete_tail(data)
        (1..[MAX_SEQUENCE - 1, data.bytesize].min).each do |back|
          byte = data.getbyte(-back)
          next if byte & 0xC0 == 0x80 # continuation byte

          return back < sequence_length(byte) ? back : 0
        end
        0
      end

      def sequence_length(lead_byte)
        if lead_byte >= 0xF0 then 4
        elsif lead_byte >= 0xE0 then 3
        elsif lead_byte >= 0xC0 then 2
        else 1
        end
      end
    end
  end
end
