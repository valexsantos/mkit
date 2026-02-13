# frozen_string_literal: true

require 'net/http'
require 'socket'

module MKIt
  class HealthCheckWorker < AWorker
    PROBE_INTERVAL = 10

    def topics
      %w[health_check]
    end

    def do_the(job)
      pod = Pod.find_by(name: job.data['pod_name'])
      return unless pod&.service

      pod.update(last_health_check_at: Time.now)

      service = pod.service
      check_liveness(pod, service.liveness_probe_config) if service.liveness_probe_config
      check_readiness(pod, service.readiness_probe_config) if service.readiness_probe_config
    end

    def check_liveness(pod, probe)
      return if skip_due_to_initial_delay?(pod, probe)

      result = execute_probe(pod, probe)
      failure_threshold = (probe['failure_threshold'] || 3).to_i

      if result
        pod.update(consecutive_liveness_failures: 0) if pod.consecutive_liveness_failures.positive?
        return
      end

      failures = pod.consecutive_liveness_failures.to_i + 1
      pod.update(consecutive_liveness_failures: failures)

      if failures >= failure_threshold
        MKItLogger.warn("Liveness probe failed #{failures}/#{failure_threshold} times for pod #{pod.name}, restarting")
        MkitJob.publish(topic: :restart_pod, pod_id: pod.id, service_id: pod.service_id)
        pod.update(consecutive_liveness_failures: 0)
      else
        MKItLogger.debug("Liveness probe failed #{failures}/#{failure_threshold} for pod #{pod.name}")
      end
    end

    def check_readiness(pod, probe)
      return if skip_due_to_initial_delay?(pod, probe)

      result = execute_probe(pod, probe)
      failure_threshold = (probe['failure_threshold'] || 3).to_i
      success_threshold = (probe['success_threshold'] || 1).to_i

      if result
        successes = pod.consecutive_readiness_successes.to_i + 1
        pod.update(consecutive_readiness_successes: successes)

        if successes >= success_threshold && !(pod.status == MKIt::Status::RUNNING) && !(pod.status == MKIt::Status::RUNNING)
            pod.update(
              consecutive_readiness_failures: 0,
              status: MKIt::Status::RUNNING
            )
        end
        return
      end

      pod.update(consecutive_readiness_successes: 0)

      failures = pod.consecutive_readiness_failures.to_i + 1
      pod.update(consecutive_readiness_failures: failures)

      return unless failures >= failure_threshold

      MKItLogger.debug("Readiness probe failed #{failures}/#{failure_threshold} for pod #{pod.name}, marking degraded")
      pod.update(status: MKIt::Status::DEGRADED)
    end

    def skip_due_to_initial_delay?(pod, probe)
      return false unless probe['initial_delay_seconds']
      return false if pod.status == MKIt::Status::RUNNING

      created_at = pod.created_at
      return false unless created_at

      elapsed = Time.now - created_at
      if elapsed < probe['initial_delay_seconds']
        MKItLogger.debug("Skipping probe for pod #{pod.name} - still in initial delay period (#{elapsed.to_i}s / #{probe['initial_delay_seconds']}s)")
        true
      else
        false
      end
    end

    def execute_probe(pod, probe)
      probe_type = probe.is_a?(Hash) ? probe['type'] : probe[:type]
      case probe_type
      when 'http'
        check_http_probe(pod, probe)
      when 'tcp'
        check_tcp_probe(pod, probe)
      when 'exec'
        check_exec_probe(pod, probe)
      else
        true
      end
    end

    def check_http_probe(pod, probe)
      return true unless pod.ip

      path = probe['path'] || '/'
      port = probe['port'] || 80
      timeout = probe['timeout_seconds'] || 5

      begin
        uri = URI("http://#{pod.ip}:#{port}#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = timeout
        http.read_timeout = timeout
        response = http.get(uri.path)
        (200..399).include?(response.code.to_i)
      rescue StandardError => e
        MKItLogger.debug("HTTP probe failed: #{e.message}")
        false
      end
    end

    def check_tcp_probe(pod, probe)
      return true unless pod.ip

      port = probe['port'] || 80
      probe['timeout_seconds'] || 5

      begin
        TCPSocket.new(pod.ip, port).close
        true
      rescue StandardError => e
        MKItLogger.debug("TCP probe failed: #{e.message}")
        false
      end
    end

    def check_exec_probe(pod, probe)
      return true unless probe['command']

      command = probe['command'].join(' ')
      `docker exec #{pod.name} sh -c '#{command}' 2>/dev/null`
      $CHILD_STATUS.success?
    end
  end
end
