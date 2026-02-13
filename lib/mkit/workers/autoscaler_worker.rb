# frozen_string_literal: true

require 'json'

module MKIt
  class AutoscalerWorker < AWorker
    SCALE_CHECK_INTERVAL = 30

    def topics
      %w[autoscaler_check]
    end

    def start
      MKItLogger.info('starting autoscaler worker')
      @thread = Thread.new do
        loop do
          sleep(SCALE_CHECK_INTERVAL)
          run_autoscaling
        end
      end
    end

    def stop
      @thread&.exit
    end

    private

    def run_autoscaling
      Service.where.not(status: MKIt::Status::STOPPED).each do |service|
        next unless service.resource
        next unless scaling_enabled?(service.resource)

        check_and_scale(service)
      end
    rescue StandardError => e
      MKItLogger.error("Autoscaler error: #{e.message}")
    end

    def scaling_enabled?(resource)
      resource.target_cpu_percent.present? || resource.target_memory_percent.present?
    end

    def check_and_scale(service)
      resource = service.resource
      current_replicas = service.pod.count

      return if current_replicas < resource.min_replicas
      return if current_replicas > resource.max_replicas

      avg_cpu = calculate_avg_cpu(service)
      avg_memory = calculate_avg_memory(service)

      target_cpu = resource.target_cpu_percent || 100
      target_memory = resource.target_memory_percent || 100

      MKItLogger.debug("Autoscaling #{service.name}: CPU=#{avg_cpu.round(1)}%/#{target_cpu}%, Memory=#{avg_memory.round(1)}%/#{target_memory}%")

      if avg_cpu > target_cpu || avg_memory > target_memory
        scale_up(service, resource, current_replicas)
      elsif avg_cpu < (target_cpu * 0.5) && avg_memory < (target_memory * 0.5)
        scale_down(service, resource, current_replicas)
      end
    end

    def calculate_avg_cpu(service)
      total_cpu = 0
      count = 0

      service.pod.each do |pod|
        cpu = get_pod_cpu_percent(pod)
        if cpu
          total_cpu += cpu
          count += 1
        end
      end

      return 0 if count.zero?

      total_cpu / count
    end

    def calculate_avg_memory(service)
      total_memory = 0
      count = 0

      service.pod.each do |pod|
        memory = get_pod_memory_percent(pod)
        if memory
          total_memory += memory
          count += 1
        end
      end

      return 0 if count.zero?

      total_memory / count
    end

    def get_pod_cpu_percent(pod)
      return nil unless pod.name

      stats = docker_stats(pod.name)
      return nil unless stats

      cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'].to_f - stats['precpu_stats']['cpu_usage']['total_usage'].to_f
      system_delta = stats['cpu_stats']['system_cpu_usage'].to_f - stats['precpu_stats']['system_cpu_usage'].to_f
      num_cpus = stats['cpu_stats']['online_cpus'] || 1

      return 0 if system_delta.zero? || cpu_delta.zero?

      ((cpu_delta / system_delta) * num_cpus * 100).round(2)
    end

    def get_pod_memory_percent(pod)
      return nil unless pod.name

      stats = docker_stats(pod.name)
      return nil unless stats

      usage = stats['memory_stats']['usage'].to_f
      limit = stats['memory_stats']['limit'].to_f

      return 0 if limit.zero?

      ((usage / limit) * 100).round(2)
    end

    def docker_stats(container_name)
      output = `docker stats --no-stream --format '{{json .}}' #{container_name} 2>/dev/null`
      return nil if output.nil? || output.empty?

      JSON.parse(output)
    rescue JSON::ParserError
      nil
    end

    def scale_up(service, resource, current_replicas)
      return if current_replicas >= resource.max_replicas
      return unless can_scale_up?(resource)

      MKItLogger.info("Scaling up #{service.name}: #{current_replicas} -> #{current_replicas + 1}")
      add_pod(service)
      resource.update(last_scale_up_at: Time.now)
    end

    def scale_down(service, resource, current_replicas)
      return if current_replicas <= resource.min_replicas
      return unless can_scale_down?(resource)

      MKItLogger.info("Scaling down #{service.name}: #{current_replicas} -> #{current_replicas - 1}")
      remove_pod(service)
      resource.update(last_scale_down_at: Time.now)
    end

    def can_scale_up?(resource)
      return true unless resource.scale_up_stabilization.positive?
      return true unless resource.last_scale_up_at

      Time.now - resource.last_scale_up_at >= resource.scale_up_stabilization
    end

    def can_scale_down?(resource)
      return true unless resource.scale_down_stabilization.positive?
      return true unless resource.last_scale_down_at

      Time.now - resource.last_scale_down_at >= resource.scale_down_stabilization
    end

    def add_pod(service)
      pd = Pod.new(status: MKIt::Status::CREATED, name: SecureRandom.uuid.gsub('-', '')[0..11])
      service.pod << pd
      MkitJob.publish(topic: :create_pod_saga, data: { pod_name: pd.name })
    end

    def remove_pod(service)
      pod = service.pod.last
      return unless pod

      pod.destroy
    end
  end
end
