# frozen_string_literal: true

require 'mkit/container/utf8_buffer'

module MKIt
  module Container
    module Docker
      # Decodes Docker's multiplexed stdout/stderr stream (containers without a
      # TTY): frames of [type, 0, 0, 0, size(4 bytes big endian)] + payload.
      # Characters split between frames of the same stream (stdout/stderr) are kept whole.
      class StreamDemux
        HEADER = 8

        def initialize
          @buffer = String.new(encoding: Encoding::BINARY)
          @texts = Hash.new { |hash, type| hash[type] = Container::Utf8Buffer.new }
        end

        # Feeds a chunk, yields the text of each complete frame.
        def feed(chunk)
          @buffer << chunk.b
          while @buffer.bytesize >= HEADER
            size = @buffer.byteslice(4, 4).unpack1('N')
            break if @buffer.bytesize < HEADER + size

            type = @buffer.getbyte(0)
            text = @texts[type].feed(@buffer.byteslice(HEADER, size))
            @buffer = @buffer.byteslice(HEADER + size..)
            yield text unless text.empty?
          end
        end

        # End of the stream: yields what was held back
        def flush
          @texts.each_value do |text|
            rest = text.flush
            yield rest unless rest.empty?
          end
        end

        def self.decode(data)
          out = +''
          demux = new
          demux.feed(data) { |text| out << text }
          demux.flush { |text| out << text }
          out
        end
      end
    end
  end
end
