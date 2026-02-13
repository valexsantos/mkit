# frozen_string_literal: true

module MKIt
  class HealthCheckScheduler
    DEFAULT_INTERVAL = 10

    def initialize(interval: DEFAULT_INTERVAL)
      @interval = interval
    end

    def start
      MKItLogger.info('starting health check scheduler')
      @thread = Thread.new do
        loop do
          sleep(@interval)
          run_health_checks
        end
      end
    end

    def stop
      @thread&.exit
    end

    private

    def run_health_checks
      Pod.where(status: MKIt::Status::RUNNING).each do |pod|
        next unless pod.service

        service = pod.service
        next unless service.liveness_probe_config || service.readiness_probe_config

        MkitJob.publish(topic: :health_check, data: { pod_name: pod.name })
      end
    rescue StandardError => e
      MKItLogger.error("Health check scheduler error: #{e.message}")
    end
  end
end
