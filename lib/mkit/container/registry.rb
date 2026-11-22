# frozen_string_literal: true

require 'mkit/container/docker/api'

module MKIt
  module Container
    # Holds the Api of the configured runtime.
    module Registry
      BUILDERS = { 'docker' => ->(socket) { Docker::Api.build(socket: socket) } }.freeze

      class << self
        def api
          @api ||= build(nil, nil)
        end

        # Selects the runtime (and its socket) used by .api.
        def configure(runtime: nil, socket: nil)
          @api = build(runtime, socket)
        end

        # Reads mkit.container.{runtime,socket}; mkit.docker.socket is the legacy key for the socket.
        def configure_from(config)
          container = config.container
          configure(runtime: container&.runtime, socket: container&.socket || config.docker&.socket)
        end

        private

        def build(runtime, socket)
          name = (runtime || 'docker').to_s
          builder = BUILDERS[name] or raise Error, "unsupported container runtime '#{name}'"
          builder.call(socket)
        end
      end
    end
  end
end
