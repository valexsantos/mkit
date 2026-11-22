# frozen_string_literal: true

require 'mkit/container/api'
require 'mkit/container/http/unix_client'
require 'mkit/container/docker/containers'
require 'mkit/container/docker/networks'
require 'mkit/container/docker/volumes'
require 'mkit/container/docker/events'

module MKIt
  module Container
    module Docker
      DEFAULT_SOCKET = '/var/run/docker.sock'

      # Container runtime backed by the Docker Engine API.
      module Api
        def self.build(socket: nil)
          client = Http::UnixClient.new(socket: socket || DEFAULT_SOCKET)
          Container::Api.new(containers: Containers.new(client), networks: Networks.new(client),
                             volumes: Volumes.new(client), events: Events.new(client))
        end
      end
    end
  end
end
