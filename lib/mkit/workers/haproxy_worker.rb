module MKIt
  class HAProxyWorker < AWorker

    def topics
      %w{create_proxy_config destroy_proxy_config update_proxy_config restart_proxy reload_proxy}
    end

    def do_the(job)
      MKItLogger.info("#{self.class} working on the job #{job.inspect}....")
      case job.topic.to_sym
      when :update_proxy_config, :create_proxy_config
        write_config(Service.find(job.service_id))
        MKIt::HAProxy.reload
      when :destroy_proxy_config
        MKIt::HAProxy.delete_config_file(filename: job.data['filename'])
        MKIt::HAProxy.reload
      when :reload_proxy
        MKIt::HAProxy.reload
      when :restart_proxy
        MKIt::HAProxy.restart
      else
        MKItLogger.warn("#{self.class} <<TODO>> job #{job.inspect}....")
      end
    end

    private

    # A service without a pod to route to has no valid config: its file must leave the config dir.
    def write_config(srv)
      if srv.routable?
        config = srv.proxy_config
        MKItLogger.debug config.inspect
        MKIt::HAProxy.create_config_file(filename: config[:filename], data: config[:data])
      else
        MKItLogger.warn("service #{srv.name} has no pod with an ip, removing its proxy config")
        MKIt::HAProxy.delete_config_file(filename: srv.proxy_filename)
      end
    end
  end
end

