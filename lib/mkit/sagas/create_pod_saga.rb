module MKIt
  class CreatePodSaga < ASaga

    def topics
      %w{create_pod_saga}
    end

    #
    # create_pod_saga:
    #
    # payload:
    #  * service_id
    #
    # triggers
    #  * nothing
    #
    def do_the(job)
      MKItLogger.info("#{self.class} <#{job.topic}> #{job.inspect}....")
      service = Service.find(job.service_id)
      # create pod

      pd = Pod.new( service: service, status: MKIt::Status::CREATED, name: SecureRandom.uuid.gsub('-','')[0..11])
      service.pod << pd
      service.save
      MkitJob.publish(topic: :start_pod, service_id: job.service_id, pod_id: pd.id)
    end
  end
end
