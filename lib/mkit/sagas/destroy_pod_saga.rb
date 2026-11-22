require 'mkit/container/registry'

module MKIt
  class DestroyPodSaga < ASaga
    def initialize(containers: Container::Registry.api.containers)
      @containers = containers
      super()
    end

    def topics
      %w{destroy_pod_saga}
    end

    #
    # destroy_pod_saga:
    #
    # payload:
    #  * pod_name
    #  * pod.id
    #
    # triggers
    #  * pod_destroyed?
    #
    def do_the(job)
      MKItLogger.info("#{self.class} <#{job.topic}> #{job.inspect}....")

      begin
        @containers.remove(job.data['pod_name'])
      rescue => e
        MKItLogger.warn(e)
      end

    end
  end
end
