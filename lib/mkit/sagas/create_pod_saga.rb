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
      MKItLogger.info("deploying pod #{pod_name} (#{spec.image})")
      run(pod_name, spec)
    end

    private

    # logs why the container could not be created or started, then lets the job fail
    def run(pod_name, spec)
      @containers.run(spec)
    rescue Container::Error => e
      MKItLogger.error("pod #{pod_name} (#{spec.image}) could not be started: #{e.message}#{status_of(e)}")
      raise
    end

    def status_of(error)
      error.status.nil? ? '' : " (status #{error.status})"
    end
  end
end
