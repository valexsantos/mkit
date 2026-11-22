require 'mkit/container/registry'

module MKIt
  class CreatePodSaga < ASaga
    def initialize(containers: Container::Registry.api.containers)
      @containers = containers
      super()
    end

    def topics
      %w{create_pod_saga}
    end

    #
    # create_pod_saga:
    #
    # payload:
    #  * pod_name
    #
    # triggers
    #  * nothing
    #
    def do_the(job)
      MKItLogger.info("#{self.class} <#{job.topic}> #{job.inspect}....")

      pod_name = job.data['pod_name']
      pod = Pod.find_by_name(pod_name)
      spec = pod.container_spec
      MKItLogger.info("deploying docker pod, spec [#{spec.to_h}]")
      @containers.run(spec)
    end
  end
end
