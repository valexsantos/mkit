require 'mkit/sagas/asaga'
require 'mkit/sagas/create_pod_saga'

module MKIt
  class SagaManager
    def self.register_workers
      CreatePodSaga.new
    end
  end
end
