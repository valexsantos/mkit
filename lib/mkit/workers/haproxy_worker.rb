module MKIt
  class HAProxyWorker < AWorker

    def topics
      %w{create_proxy_config destroy_proxy_config update_proxy_config restart_proxy reload_proxy}
    end

    def do_the(job)
      MKItLogger.info("#{self.class} working on the job #{job.inspect}....")
      unless job.service_id.nil?
        srv = Service.find(job.service_id)
        config = srv.proxy_config
      end
      case job.topic.to_sym
      when :update_proxy_config
        MKItLogger.debug config.inspect
        MKIt::HAProxy.create_config_file(filename: config[:filename], data: config[:data])
        MKIt::HAProxy.reload
      when :destroy_proxy_config
        MKIt::HAProxy.delete_config_file(filename: job.data['filename'])
        MKIt::HAProxy.reload
      when :create_proxy_config
        MKIt::HAProxy.create_config_file(filename: config[:filename], data: config[:data])
        MKIt::HAProxy.reload
      when :reload_proxy
        MKIt::HAProxy.reload
      when :restart_proxy
        MKIt::HAProxy.restart
      else
        MKItLogger.warn("#{self.class} <<TODO>> job #{job.inspect}....")
      end
    end
  end
end

