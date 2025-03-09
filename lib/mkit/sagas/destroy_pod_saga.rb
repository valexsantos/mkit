require 'mkit/app/helpers/docker_helper'

module MKIt
  class DestroyPodSaga < ASaga
    include MKIt::DockerHelper

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
        remove_instance(job.data['pod_name'])
      rescue => e
        MKItLogger.warn(e)
      end

    end
  end
end
