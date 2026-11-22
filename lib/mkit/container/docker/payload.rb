# frozen_string_literal: true

module MKIt
  module Container
    module Docker
      # Builds the Docker Engine API "create container" payload from a Container::Spec.
      class Payload
        MIB = 1024 * 1024

        def initialize(spec)
          @spec = spec
        end

        def to_h
          payload = { 'Image' => @spec.image, 'Env' => @spec.env, 'HostConfig' => host_config }
          cmd = @spec.command
          payload['Cmd'] = cmd unless cmd.empty?
          payload
        end

        private

        def host_config
          {
            'Binds' => @spec.binds,
            'NetworkMode' => @spec.network,
            'Dns' => [@spec.dns]
          }.merge(limits)
        end

        def limits
          {
            'NanoCpus' => @spec.cpu_millicores&.*(1_000_000),
            'Memory' => @spec.memory_mib&.*(MIB),
            'MemorySwap' => @spec.memory_swap_mib&.*(MIB)
          }.compact
        end
      end
    end
  end
end
