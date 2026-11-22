# frozen_string_literal: true

require 'mkit/container/events'
require 'mkit/container/docker/mapper'

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
          @client.stream('/events') { |payload| block.call(Mapper.event(payload)) }
        end
      end
    end
  end
end
