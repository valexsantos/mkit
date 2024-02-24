require 'mkit/app/model/service'
require 'mkit/exceptions'

class ServicePort < ActiveRecord::Base
  belongs_to :service

  CONFIG_EXPRESSION=/^(.*?):(.*?):(tcp|http):(.*?)($|:ssl$|:ssl,(.+))$/

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
  #     # ssl support:
  #     # src:dest:tcp|http:round_robin|leastconn[:ssl[,<cert.pem>(mkit.pem default)>]]
  #     - 443:80:tcp:round_robin:ssl # crt file is mkit.pem
  #     - 443:80:tcp:round_robin:ssl,/etc/pki/foo.pem # crt file full path
  # model:
  #  service_ports:
  #     - external: 5432
  #       internal: 5432
  #       mode: tcp|http
  #       load_bal: round_robin
  #       ssl: true|false
  #       crt: full path
  def parse_config(config)
    ports = config.match(CONFIG_EXPRESSION)
    raise MKIt::InvalidPortsConfiguration.new("no match with config expression $#{CONFIG_EXPRESSION}") if ports.nil?

    puts ports
    self.external_port = ports[1]
    self.internal_port = ports[2]
    self.mode = ports[3]
    self.load_bal = ports[4]
    self.ssl = !ports[5].nil? && ports[5].start_with?(':ssl') ? 'true':'false'
    self.crt = ports[7].nil? ? MKIt::Utils.proxy_cert : ports[7]
  end

  def ssl
    super == 'true'
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
