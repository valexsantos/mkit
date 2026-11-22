require 'mkit/container/registry'
require 'mkit/container/errors'

module MKIt
  # Brings the pods (container id, ip, dns) and the proxy config back in sync with the containers.
  #
  # Needed when events may have been lost: on startup and every time the event stream is
  # reestablished (the runtime restarted, the socket dropped).
  # A service whose pod ips changed gets a single update_proxy_config job, however many of its pods changed.
  class PodReconciler
    def initialize(containers: Container::Registry.api.containers)
      @containers = containers
    end

    # returns the services whose proxy config was refreshed
    def call
      changed = {}
      Pod.all.each do |pod|
        service = pod.service
        next if service.nil?

        changed[service.id] = service if sync(pod)
      end
      changed.each_value { |service| refresh(service) }
      MKItLogger.info("pods reconciled, #{changed.size} service(s) with a new proxy config")
      changed.values
    end

    private

    # true when the ip of the pod changed
    def sync(pod)
      info = @containers.find(pod.name)
      pod.sync_ip(info, notify: false)
      ip_changed = pod.saved_change_to_ip?
      pod.update!(pod_id: info.id) if info && pod.pod_id != info.id
      ip_changed
    rescue Container::Error => e
      MKItLogger.warn("could not reconcile pod #{pod.name}: #{e.message}")
      false
    end

    def refresh(service)
      MkitJob.publish(topic: :update_proxy_config, service_id: service.id)
      service.update_status!
    end
  end
end
