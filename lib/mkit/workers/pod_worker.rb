#
module MKIt
  class PodWorker < AWorker

    def topics
      %w{pod_network_connected pod_network_disconnected
          pod_unhealthy 
          start_pod stop_pod update_pod deploy_pod destroy_pod
          pod_ip_updated pod_destroyed
      }
    end

    def do_the(job)
      MKItLogger.info("#{self.class} <#{job.topic}> job #{job.inspect}....")
      pod = Pod.find(job.pod_id) unless job.pod_id.nil?
      case job.topic.to_sym
      when :deploy_pod
        MKItLogger.warn("#{self.class} @deprecated job #{job.inspect}....")
      when :start_pod
        pod.start
      when :stop_pod
        pod.stop
      when :destroy_pod
        pod.stop
        pod.destroy
      when :pod_destroyed
        if Service.exists?(job.service_id)
          MkitJob.publish(topic: :update_proxy_config, service_id: job.service_id)
        end
      when :pod_ip_updated
        if Service.exists?(job.service_id)
          MkitJob.publish(topic: :update_proxy_config, service_id: job.service_id)
        end
      else
        MKItLogger.info("#{self.class} <<TODO>> job #{job.inspect}....")
      end
    end

  end
end

