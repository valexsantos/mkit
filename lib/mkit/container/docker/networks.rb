# frozen_string_literal: true

require 'mkit/container/networks'

module MKIt
  module Container
    module Docker
      # Network operations through the Docker Engine API.
      class Networks < Container::Networks
        def initialize(client)
          super()
          @client = client
        end

        def create(name)
          @client.post('/networks/create', 'Name' => name)
        end

        def find(name)
          @client.get("/networks/#{name}")
        end

        def attach(network, container)
          @client.post("/networks/#{network}/connect", 'Container' => container)
        end

        def detach(network, container)
          @client.post("/networks/#{network}/disconnect", 'Container' => container)
        end

        def remove(network)
          @client.delete("/networks/#{network}")
        end
      end
    end
  end
end
