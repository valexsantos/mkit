# frozen_string_literal: true

require 'mkit/container/events'

module MKIt
  module Container
    module Docker
      # https://docs.docker.com/engine/api/v1.43/#tag/System/operation/SystemEvents
      class Events < Container::Events
        def initialize(client)
          super()
          @client = client
        end

        def each(&block)
          @client.stream('/events', &block)
        end
      end
    end
  end
end
