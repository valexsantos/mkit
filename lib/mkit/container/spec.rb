# frozen_string_literal: true

require 'shellwords'
require 'mkit/ctypes'

module MKIt
  module Container
    # Runtime neutral description of the container a pod needs.
    class Spec
      attr_reader :name

      def initialize(name:, service:)
        @name = name
        @service = service
      end

      def image
        @service.image
      end

      def env
        (@service.service_config || [])
          .select { |c| c.ctype == MKIt::CType::ENVIRONMENT.to_s }
          .map { |c| "#{c.key}=#{c.value}" }
      end

      def binds
        (@service.volume || []).map { |v| "#{v.name}:#{v.path}" }
      end

      def command
        Shellwords.split(@service.command.to_s)
      end

      def network
        @service.pods_network
      end

      def dns
        @service.my_dns
      end

      # Limits are expressed as '\d+m' (millicores / MiB), see Resource.validate
      def cpu_millicores
        amount(resource&.cpu_limits)
      end

      def memory_mib
        amount(resource&.memory_limits)
      end

      def memory_swap_mib
        amount(resource&.memory_swap_limits)
      end

      private

      def resource
        @service.resource
      end

      def amount(value)
        value.nil? ? nil : value.to_s.delete_suffix('m').to_i
      end
    end
  end
end
