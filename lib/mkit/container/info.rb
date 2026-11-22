# frozen_string_literal: true

module MKIt
  module Container
    # Runtime neutral view of an existing container.
    class Info
      attr_reader :id, :name, :addresses, :exit_code, :error

      # addresses: { network name => ip }
      # exit_code: of the last run (nil when it never ran); error: runtime message about a failed start/run
      def initialize(id:, name:, running: false, tty: false, addresses: {}, exit_code: nil, oom_killed: false, error: nil)
        @id = id
        @name = name
        @running = running
        @tty = tty
        @addresses = addresses
        @exit_code = exit_code
        @oom_killed = oom_killed
        @error = error.to_s.empty? ? nil : error
      end

      def oom_killed?
        @oom_killed
      end

      def running?
        @running
      end

      def tty?
        @tty
      end

      # ip of the container in the network, nil while none is assigned
      def ip_on(network)
        ip = @addresses[network]
        ip.nil? || ip.empty? ? nil : ip
      end
    end
  end
end
