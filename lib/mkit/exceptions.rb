module MKIt
  class BaseException < Exception
    attr_reader :error_code
    def initialize(error_code, message = nil)
      super(message)
      @error_code = error_code
    end
  end

  class ServiceAlreadyExists < BaseException
    def initialize(message = nil)
      super(409, message)
    end
  end
  class ServiceNameMismatch < BaseException
    def initialize(message = nil)
      super(400, message)
    end
  end
  class InvalidPortsConfiguration < BaseException
    def initialize(message = nil)
      super(400, message)
    end
  end
  class ServiceNotFoundException < StandardError; end
  class PodNotFoundException     < StandardError; end
  class AppAlreadyDeployedException < StandardError; end
  class InvalidPortMappingTypeException < StandardError; end

  class PoolExaustedException < StandardError; end

  class CmdRunnerException < StandardError; end

end

