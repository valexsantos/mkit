# frozen_string_literal: true

module MKIt
  module Container
    # Runtime neutral view of an existing container.
    class Info
      attr_reader :id, :name, :addresses

      # addresses: { network name => ip }
      def initialize(id:, name:, running: false, tty: false, addresses: {})
        @id = id
        @name = name
        @running = running
        @tty = tty
        @addresses = addresses
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
