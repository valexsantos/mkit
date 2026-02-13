require 'mkit/workers/aworker'
require 'mkit/workers/service_worker'
require 'mkit/workers/pod_worker'
require 'mkit/workers/haproxy_worker'
require 'mkit/workers/health_check_worker'
require 'mkit/workers/health_check_scheduler'
require 'mkit/workers/autoscaler_worker'

module MKIt
  class WorkerManager
    def self.register_workers
      ServiceWorker.new
      PodWorker.new
      HAProxyWorker.new
      HealthCheckWorker.new
      HealthCheckScheduler.new
      AutoscalerWorker.new
    end
  end
end
  end
end
