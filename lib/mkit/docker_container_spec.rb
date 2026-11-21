require 'shellwords'
require 'mkit/ctypes'

module MKIt
  # Builds the Docker Engine API "create container" payload for a pod.
  class DockerContainerSpec
    MIB = 1024 * 1024

    def initialize(name:, service:)
      @name = name
      @service = service
    end

    attr_reader :name

    def image
      @service.image
    end

    def to_h
      payload = {
        'Image' => image,
        'Env' => env,
        'HostConfig' => host_config
      }
      cmd = command
      payload['Cmd'] = cmd unless cmd.empty?
      payload
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

    private

    def host_config
      {
        'Binds' => binds,
        'NetworkMode' => @service.pods_network,
        'Dns' => [@service.my_dns]
      }.merge(limits)
    end

    # Limits are expressed as '\d+m' (millicores / MiB), see Resource.validate
    def limits
      res = @service.resource
      return {} if res.nil?

      {
        'NanoCpus' => amount(res.cpu_limits)&.*(1_000_000),
        'Memory' => amount(res.memory_limits)&.*(MIB),
        'MemorySwap' => amount(res.memory_swap_limits)&.*(MIB)
      }.compact
    end

    def amount(value)
      value.nil? ? nil : value.to_s.delete_suffix('m').to_i
    end
  end
end
