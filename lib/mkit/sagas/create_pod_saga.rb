require 'mkit/app/helpers/docker_helper'

module MKIt
  class CreatePodSaga < ASaga
    include MKIt::DockerHelper

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
      docker_run = pod.parse
      MKItLogger.info("deploying docker pod, cmd [#{docker_run}]")
      create_instance(docker_run)
    end
  end
end
