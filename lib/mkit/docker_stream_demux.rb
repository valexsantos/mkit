# frozen_string_literal: true

module MKIt
  # Decodes Docker's multiplexed stdout/stderr stream (containers without a
  # TTY): frames of [type, 0, 0, 0, size(4 bytes big endian)] + payload.
  class DockerStreamDemux
    HEADER = 8

    def initialize
      @buffer = String.new(encoding: Encoding::BINARY)
    end

    # Feeds a chunk, yields the payload of each complete frame.
    def feed(chunk)
      @buffer << chunk.b
      while @buffer.bytesize >= HEADER
        size = @buffer.byteslice(4, 4).unpack1('N')
        break if @buffer.bytesize < HEADER + size

        yield @buffer.byteslice(HEADER, size).force_encoding(Encoding::UTF_8)
        @buffer = @buffer.byteslice(HEADER + size..)
      end
    end

    def self.decode(data)
      out = +''
      new.feed(data) { |payload| out << payload }
      out
    end
  end
end
