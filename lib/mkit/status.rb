#
#
#
module MKIt
  class MKItStatus
    def initialize(status)
      @status = status
    end
    def to_s
      @status.to_s
    end
  end

  module Status
    # APP
    CREATED   = 'CREATED'
    CREATING  = 'CREATING'
    DEPLOYING = 'DEPLOYING'
    DEPLOYED  = 'DEPLOYED'
    PENDING   = 'PENDING'
    DEGRATED  = 'DEGRATED'

    # network
    RESERVED = 'RESERVED'
    IN_USE   = 'IN_USE'
    EXPIRED  = 'EXPIRED'

    # pods
    STARTING = 'STARTING'
    RUNNING  = 'RUNNING'
    STOPPED  = 'STOPPED'
    STOPING  = 'STOPING'
    PAUSED   = 'PAUSED'

    # Service
    RESTARTING = 'RESTARTING'
    UPDATING   = 'UPDATING'
  end

  module PoolStatus
    
    RESERVED = 'RESERVED'
    IN_USE   = 'IN_USE'
    EXPIRED  = 'EXPIRED'
    EXAUSTED = 'EXAUSTED'
  end
end
