require 'mkit/app/model/service'
require 'mkit/exceptions'

class ServicePort < ActiveRecord::Base
  belongs_to :service

  CONFIG_EXPRESSION=/^(.*?):(.*?):(tcp|http):(.*?)$/

  def self.create(service:, config:)
    sp = ServicePort.new(service: service, version: service.version)
    sp.parse_config(config)
    sp
  end

  # haproxy support for port range - leave dest blank
  # service:
  #   ports:
  #     # src:dest:tcp|http:round_robin|leastconn
  #     - 5532:5432:tcp:round_robin
  #     - 5532-6000::tcp:round_robin
  # model:
  #  service_ports:
  #     - external: 5432
  #       internal: 5432
  #       mode: tcp|http
  #       load_bal: round_robin
  def parse_config(config)
    ports = config.match(CONFIG_EXPRESSION)
    raise MKIt::InvalidPortsConfiguration.new("no match with config expression $#{CONFIG_EXPRESSION}") if ports.nil?

    self.external_port = ports[1]
    self.internal_port = ports[2]
    self.mode = ports[3]
    self.load_bal = ports[4]
  end

  def load_balance
    case self.load_bal
    when /^round_robin$/
      "roundrobin"
    when /^leastconn$/
      "leastconn"
    else
      "roundrobin"
    end
  end
end
