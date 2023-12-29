module MKIt
  class ServiceWorker < AWorker

    def topics
      %w{start_service stop_service update_service delete_service}
    end

    def do_the(job)
      MKItLogger.info("#{self.class} <#{job.topic}> job #{job.inspect}....")
      srv = Service.find(job.service_id)
      case job.topic.to_sym
      when :start_service
        srv.start
      when :stop_service
        srv.stop
      when :update_service
        MKItLogger.info("#{self.class} <#{job.topic}> <<TODO>> job #{job.inspect}....")
      when :delete_service
        Service.destroy(job.service_id)
      else
        MKItLogger.info("#{self.class} <#{job.topic}> <<TODO>> job #{job.inspect}....")
      end
    end

  end
end

