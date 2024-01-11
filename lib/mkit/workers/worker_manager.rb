require 'mkit/workers/aworker'
require 'mkit/workers/service_worker'
require 'mkit/workers/pod_worker'
require 'mkit/workers/haproxy_worker'

module MKIt
  class WorkerManager
    def self.register_workers
      ServiceWorker.new
      PodWorker.new
      HAProxyWorker.new
    end
  end
end
