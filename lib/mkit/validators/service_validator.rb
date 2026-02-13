# frozen_string_literal: true

require 'json/schema'

module MKIt
  module Validators
    class ServiceSchema
      SCHEMA = {
        '$schema' => 'http://json-schema.org/draft-07/schema#',
        'type' => 'object',
        'required' => ['service'],
        'properties' => {
          'service' => {
            'type' => 'object',
            'required' => %w[name image],
            'properties' => {
              'name' => {
                'type' => 'string',
                'pattern' => '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$',
                'minLength' => 1,
                'maxLength' => 253
              },
              'image' => {
                'type' => 'string',
                'minLength' => 1
              },
              'command' => {
                'type' => 'array',
                'items' => { 'type' => 'string' }
              },
              'network' => {
                'type' => 'string'
              },
              'resources' => {
                'type' => 'object',
                'properties' => {
                  'min_replicas' => { 'type' => 'integer', 'minimum' => 0, 'maximum' => 10 },
                  'max_replicas' => { 'type' => 'integer', 'minimum' => 0, 'maximum' => 10 },
                  'limits' => {
                    'type' => 'object',
                    'properties' => {
                      'cpu' => { 'type' => 'string', 'pattern' => '^[0-9]+m?$' },
                      'memory' => { 'type' => 'string', 'pattern' => '^[0-9]+(Mi|Gi|M)$' }
                    }
                  },
                  'scaling' => {
                    'type' => 'object',
                    'properties' => {
                      'target_cpu_percent' => { 'type' => 'integer', 'minimum' => 0, 'maximum' => 100 },
                      'target_memory_percent' => { 'type' => 'integer', 'minimum' => 0, 'maximum' => 100 },
                      'scale_up_stabilization_seconds' => { 'type' => 'integer', 'minimum' => 0 },
                      'scale_down_stabilization_seconds' => { 'type' => 'integer', 'minimum' => 0 }
                    }
                  }
                }
              },
              'volumes' => {
                'type' => 'array',
                'items' => { 'type' => 'string', 'pattern' => '^(docker:\/\/|persistent:\/\/|/).*$' }
              },
              'environment' => {
                'type' => 'object',
                'additionalProperties' => { 'type' => 'string' }
              },
              'ingress' => {
                'type' => 'object',
                'properties' => {
                  'frontend' => { 'type' => 'array' },
                  'backend' => { 'type' => 'array' }
                }
              },
              'liveness_probe' => {
                'type' => 'object',
                'properties' => {
                  'type' => { 'type' => 'string', 'enum' => %w[http tcp exec] },
                  'path' => { 'type' => 'string' },
                  'port' => { 'type' => 'integer' },
                  'initial_delay_seconds' => { 'type' => 'integer', 'minimum' => 0 },
                  'period_seconds' => { 'type' => 'integer', 'minimum' => 1 },
                  'timeout_seconds' => { 'type' => 'integer', 'minimum' => 1 },
                  'failure_threshold' => { 'type' => 'integer', 'minimum' => 1 },
                  'success_threshold' => { 'type' => 'integer', 'minimum' => 1 },
                  'command' => { 'type' => 'array', 'items' => { 'type' => 'string' } }
                }
              },
              'readiness_probe' => {
                'type' => 'object',
                'properties' => {
                  'type' => { 'type' => 'string', 'enum' => %w[http tcp exec] },
                  'path' => { 'type' => 'string' },
                  'port' => { 'type' => 'integer' },
                  'initial_delay_seconds' => { 'type' => 'integer', 'minimum' => 0 },
                  'period_seconds' => { 'type' => 'integer', 'minimum' => 1 },
                  'timeout_seconds' => { 'type' => 'integer', 'minimum' => 1 },
                  'failure_threshold' => { 'type' => 'integer', 'minimum' => 1 },
                  'success_threshold' => { 'type' => 'integer', 'minimum' => 1 },
                  'command' => { 'type' => 'array', 'items' => { 'type' => 'string' } }
                }
              }
            }
          }
        }
      }.freeze

      def self.validate(yaml)
        result = JSON::Schema.validate(yaml, SCHEMA)
        return [] if result.empty?

        result.map(&:message)
      end

      def self.validate_vault_refs(yaml)
        return [] if yaml['service'].nil? || yaml['service']['environment'].nil?

        errors = []
        yaml['service']['environment'].each do |_key, value|
          next unless value.to_s.start_with?('vault://')

          validation = VaultSecret.validate_path(value)
          errors << validation[:error] unless validation[:valid]
        end
        errors
      end

      def self.valid?(yaml)
        validate(yaml).empty?
      end
    end
  end
end
