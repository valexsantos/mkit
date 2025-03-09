require 'mkit/sagas/asaga'
require 'mkit/sagas/create_pod_saga'
require 'mkit/sagas/destroy_pod_saga'

module MKIt
  class SagaManager
    def self.register_workers
      CreatePodSaga.new
      DestroyPodSaga.new
    end
  end
end
