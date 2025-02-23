#
#
module MKIt
    class MKItCType
      def initialize(status)
        @status = status.to_s
      end

      def to_s
        @status.downcase
      end
    end
  
    module CType
        ENVIRONMENT = MKIt::MKItCType.new(:environment)
        DOCKER_STORAGE = MKIt::MKItCType.new(:docker)
        LOCAL_STORAGE = MKIt::MKItCType.new(:local)

        NETWORK_SPECIFIC = MKIt::MKItCType.new(:specific)
        NETWORK_BRIDGE = MKIt::MKItCType.new(:bridge)
        TUN_INTERFACE = MKIt::MKItCType.new(:tun)
        TAP_INTERFACE = MKIt::MKItCType.new(:tap)
    end

    module Templates
      DOCKER_RUN = 'docker/docker_run.sh'
      DOCKER_BUILD = 'docker/docker_build.sh'
      HAPROXY = 'haproxy/app_haproxy.cfg'
      HAPROXY_DEFAULTS = 'haproxy/0000_defaults.cfg'
    end
end
