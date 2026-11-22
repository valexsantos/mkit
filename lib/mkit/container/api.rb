# frozen_string_literal: true

require 'mkit/container/containers'
require 'mkit/container/networks'
require 'mkit/container/volumes'
require 'mkit/container/events'

module MKIt
  module Container
    # Entry point of a container runtime: groups its resources.
    class Api
      attr_reader :containers, :networks, :volumes, :events

      def initialize(containers:, networks:, volumes:, events:)
        @containers = containers
        @networks = networks
        @volumes = volumes
        @events = events
      end
    end
  end
end
