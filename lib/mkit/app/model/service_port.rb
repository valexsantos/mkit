require 'mkit/app/model/service'

class ServicePort < ActiveRecord::Base
  belongs_to :service

  def self.create(service:, config:)
    sp = ServicePort.new(service: service, version: service.version)
    sp.parse_config(config)
    sp
  end

  # haproxy support for port range - leave src blank
  # service:
  #   ports:
  #     # src:dest:tcp|http:load-balancing
  #     - 5532:5432:tcp:round_robin
  # model:
  #  service_ports:
  #     - external: 5432
  #       internal: 5432
  #       mode: tcp|http
  #       load_bal:
  def parse_config(config)
    ports = config.split(':')
    self.external_port = ports[0]
    self.internal_port = ports[1]
    self.mode = ports[2]
    self.load_bal = ports[3]
  end
end
