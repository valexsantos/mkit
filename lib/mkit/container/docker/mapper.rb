# frozen_string_literal: true

require 'mkit/container/info'
require 'mkit/container/event'

module MKIt
  module Container
    module Docker
      # Translates Docker Engine API payloads to the runtime neutral value objects.
      module Mapper
        module_function

        # container inspect (GET /containers/{id}/json) => Info
        def info(inspect)
          Info.new(
            id: inspect['Id'],
            name: inspect['Name'].to_s.delete_prefix('/'),
            running: inspect.dig('State', 'Running') == true,
            tty: inspect.dig('Config', 'Tty') == true,
            addresses: addresses(inspect)
          )
        end

        # event of GET /events => Event
        def event(payload)
          attributes = payload.dig('Actor', 'Attributes') || {}
          kind = payload['Type'].to_s.to_sym
          Event.new(
            kind: kind,
            action: payload['Action'].to_s.split(':').first.to_s.strip.to_sym,
            container_id: container_id(kind, payload, attributes),
            container_name: kind == :container ? attributes['name'] : nil
          )
        end

        def addresses(inspect)
          (inspect.dig('NetworkSettings', 'Networks') || {}).transform_values { |net| net['IPAddress'] }
        end

        # network events carry the container in the attributes
        def container_id(kind, payload, attributes)
          case kind
          when :container then payload['id'] || payload.dig('Actor', 'ID')
          when :network then attributes['container']
          end
        end
      end
    end
  end
end
