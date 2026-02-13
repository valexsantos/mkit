# frozen_string_literal: true

require 'json'

module MKIt
  module Metrics
    class Collector
      def initialize
        @metrics = []
      end

      def collect
        @metrics.clear
        collect_service_metrics
        collect_pod_metrics
        collect_system_metrics
        @metrics.join("\n")
      end

      private

      def collect_service_metrics
        Service.all.each do |service|
          replica_count = service.pod.count
          running_count = service.pod.where(status: MKIt::Status::RUNNING).count

          @metrics << "mkit_service_replicas{name=\"#{service.name}\"} #{replica_count}"
          @metrics << "mkit_service_replicas_running{name=\"#{service.name}\"} #{running_count}"
          @metrics << "mkit_service_version{name=\"#{service.name}\"} #{service.version}"
        end

        @metrics << "mkit_services_total #{Service.count}"
      end

      def collect_pod_metrics
        Pod.all.each do |pod|
          next unless pod.service

          service_name = pod.service.name
          @metrics << "mkit_pod_info{name=\"#{pod.name}\",service=\"#{service_name}\"} 1"
          @metrics << "mkit_pod_status{name=\"#{pod.name}\",status=\"#{pod.status}\"} 1"

          cpu = get_pod_cpu(pod)
          memory = get_pod_memory(pod)

          @metrics << "mkit_pod_cpu_percent{name=\"#{pod.name}\"} #{cpu}" if cpu
          @metrics << "mkit_pod_memory_percent{name=\"#{pod.name}\"} #{memory}" if memory
        end

        @metrics << "mkit_pods_total #{Pod.count}"
      end

      def collect_system_metrics
        @metrics << "mkit_cpu_count #{cpu_count}"
        @metrics << "mkit_memory_total_bytes #{memory_total}"
        @metrics << "mkit_services_count #{Service.count}"
        @metrics << "mkit_pods_count #{Pod.count}"
      end

      def get_pod_cpu(pod)
        return nil unless pod.name

        stats = docker_stats(pod.name)
        return nil unless stats

        cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'].to_f - stats['precpu_stats']['cpu_usage']['total_usage'].to_f
        system_delta = stats['cpu_stats']['system_cpu_usage'].to_f - stats['precpu_stats']['system_cpu_usage'].to_f
        num_cpus = stats['cpu_stats']['online_cpus'] || 1

        return 0 if system_delta.zero? || cpu_delta.zero?

        ((cpu_delta / system_delta) * num_cpus * 100).round(2)
      rescue StandardError
        nil
      end

      def get_pod_memory(pod)
        return nil unless pod.name

        stats = docker_stats(pod.name)
        return nil unless stats

        usage = stats['memory_stats']['usage'].to_f
        limit = stats['memory_stats']['limit'].to_f

        return 0 if limit.zero?

        ((usage / limit) * 100).round(2)
      rescue StandardError
        nil
      end

      def docker_stats(container_name)
        output = `docker stats --no-stream --format '{{json .}}' #{container_name} 2>/dev/null`
        return nil if output.nil? || output.empty?

        JSON.parse(output)
      rescue JSON::ParserError
        nil
      end

      def cpu_count
        `nproc`.to_i.nonzero? || 1
      rescue StandardError
        1
      end

      def memory_total
        meminfo = begin
                    File.read('/proc/meminfo')
        rescue StandardError
                    ''
        end
        total = meminfo.match(/MemTotal:\s+(\d+)/)
        begin
          (total[1].to_i * 1024)
        rescue StandardError
          0
        end
      end
    end
  end
end
