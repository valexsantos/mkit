# frozen_string_literal: true

require 'mkit/container/volumes'

module MKIt
  module Container
    module Docker
      # Volume operations through the Docker Engine API.
      class Volumes < Container::Volumes
        def initialize(client)
          super()
          @client = client
        end

        def create(name)
          @client.post('/volumes/create', 'Name' => name)
        end

        def find(name)
          @client.get("/volumes/#{name}")
        end

        def remove(name)
          @client.delete("/volumes/#{name}")
        end
      end
    end
  end
end
