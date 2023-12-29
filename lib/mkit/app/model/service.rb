require 'mkit/app/model/volume'
require 'mkit/app/model/service_port'
require 'mkit/app/model/service_config'
require 'mkit/app/model/pod'
require 'mkit/app/helpers/erb_helper'
require 'mkit/app/helpers/docker_helper'
require 'mkit/mkit_interface'
require 'mkit/status'
require 'mkit/utils'
require 'mkit/ctypes'
require 'mkit/app/model/pool'
require 'mkit/app/model/service'
require 'mkit/app/model/pod'
require 'mkit/app/model/dns_host'
require 'mkit/app/helpers/erb_helper'
require 'mkit/app/helpers/docker_helper'
require 'mkit/app/helpers/haproxy'

#
class Service < ActiveRecord::Base
  has_many   :pod, dependent: :destroy
  has_many   :volume, dependent: :destroy
  has_many   :service_config, dependent: :destroy
  has_many   :service_port, dependent: :destroy

  has_one  :lease, dependent: :destroy
  has_one  :dns_host, dependent: :destroy

  before_destroy :clean_up

  validates :name, uniqueness: true
  validates :name, presence: true

  include MKIt::ERBHelper
  include MKIt::DockerHelper

  def self.create(yaml)
    config = yaml["service"]
    raise MKIt::ServiceAlreadyExists.new unless Service.find_by_name(config.name).nil?

    srv = Service.new(
      name: config.name,
      version: 1,
      image: config.image,
      command: config.command,
      status: MKIt::Status::CREATING
    )

    # docker network
    if config.network.nil? || config.network.empty?
      srv.pods_network="mkit"
    else
      srv.pods_network=config.network
    end

    # reserve pool ip
    srv.lease = Pool.find_by_name(MKIt::Utils.me).reserve_for(srv)

    srv.dns_host = DnsHost.new(
      service: srv,
      name: srv.name,
      ip: srv.lease.ip
    )

    # create service network
    srv.deploy_network

    # haproxy ports
    config.ports&.each do |p|
      port = ServicePort.create(service: srv, config: p)
      srv.service_port << port
    end
    # configure
    srv.configure(config)
    #
    srv.status = MKIt::Status::CREATED
    srv.save
    data = { service_id: srv.id, version: srv.version }
    # create pod
    (1..srv.min_replicas).each { |i|
      MkitJob.publish(topic: :create_pod_saga, service_id: srv.id, data: data)
    }
    srv
  end

  def configure(config)
    self.image = config.image if config.image != self.image
    self.command = config.command if config.command != self.command

    self.max_replicas = config.resources.max_replicas unless config.resources.max_replicas.nil? || config.resources.max_replicas < 1
    self.min_replicas = config.resources.min_replicas unless config.resources.min_replicas.nil? || config.resources.min_replicas < 1
    self.max_replicas = self.min_replicas if self.min_replicas > self.max_replicas

    # volumes
    self.volume = []
    config.volumes&.each { |volume|
      self.add_volume(volume)
    }
    # environment
    self.service_config=[]
    config.environment&.each_pair { |key,value|
      self.add_service_config(key, value)
    }
    self.volume.each { | volume |
      volume.deploy
    }
  end

  def update!(yaml)
    config = yaml["service"]
    self.version+=1
    self.configure(config)

    # start new pod, destroy old pod...
    self.pod.each { |pod| MkitJob.publish(topic: :destroy_pod, pod_id: pod.id, data: {}) }
    # create pod
    data = { service_id: self.id, version: self.version }
    (1..self.min_replicas).each { |i|
      MkitJob.publish(topic: :create_pod_saga, service_id: self.id, data: data)
    }
    self.save
  end

  def create_pods_network
    netw = inspect_network(self.pods_network)
    create_network(self.pods_network) if netw.nil?
  end

  def deploy_network
    # create service interface...
    self.lease.confirm
    self.lease.up
    # ...and pods network
    self.create_pods_network
  end

  def add_volume(volume_config)
    v = Volume.create(self, volume_config)
    self.volume << v
    v
  end

  def add_service_config(key, value)
    v = ServiceConfig.create(service: self, key: key, value: value)
    self.service_config << v
    v
  end

  def current_configs
    self.service_config&.select{ |x| x.ctype == MKIt::CType::ENVIRONMENT.to_s && x.version == self.version}
  end

  def current_ports
    self.service_port&.select{ |x| x.version == self.version}
  end

  def my_dns
    MKIt::Interface.ip
  end

  def update_status!
    combined_status = nil
    self.pod.each { |pod|
      child_status = pod.set_status_from_docker
      if combined_status
        case combined_status
        when MKIt::Status::RUNNING
          case child_status
          when MKIt::Status::STOPPED || MKIt::Status::PENDING
            combined_status = MKIt::Status::DEGRATED
          end
        when MKIt::Status::STOPPED
          case child_status
          when MKIt::Status::RUNNING || MKIt::Status::PENDING
            combined_status = MKIt::Status::DEGRATED
          end
        when MKIt::Status::PENDING
          case child_status
          when MKIt::Status::RUNNING || MKIt::Status::STOPPED
            combined_status = MKIt::Status::DEGRATED
          end
        end
      else
        combined_status = child_status
      end
    }
    combined_status = MKIt::Status::CREATING unless combined_status
    self.status = combined_status
    self.save
    self.status
  end

  #
  # ha proxy configs & template
  #
  def public_ports
    self.service_port.each.map{|p| p.external_port}.uniq
  end

  def ports_by_external(external_port)
    self.service_port.where('external_port = ?', external_port)
  end

  def ports_mode_by_external(external_port)
    ports = self.service_port.where('external_port = ?', external_port).first
    ports.mode if ports
  end

  def update_proxy
    MkitJob.publish(topic: :update_proxy_config, application_id: self.id, data: proxy_config)
  end

  def proxy_config
    # config
    haproxy = parse
    my_addr = self.lease.ip.split('.')[3]
    filename = "#{'%04i' % my_addr.to_i}_#{self.name}.cfg"
    MKItLogger.debug("haproxy config file: #{filename}")
    {filename: filename, data: haproxy}
  end

  def parse
    parse_model(MKIt::Templates::HAPROXY).result(binding)
  end

  def clean_up
    my_addr = self.lease.ip.split('.')[3]
    filename = "#{'%04i' % my_addr.to_i}_#{self.name}.cfg"
    MkitJob.publish(topic: :destroy_proxy_config, data: {filename: filename})
  end

  #
  # ctrl
  #
  def start
    self.pod.each { |p|
      MkitJob.publish(topic: :start_pod, service_id: self.id, pod_id: p.id)
    }
  end

  def stop
    self.pod.each { |p|
      MkitJob.publish(topic: :stop_pod, service_id: self.id, pod_id: p.id)
    }
  end

  def as_json(options = {})
    srv = super
    a=[:pod, :volume, :service_config, :service_port]
    a.each { | k | 
      srv[k] ||= []
      self.send(k).each { |v| 
        srv[k] << v.as_json
      }
    }
    srv
  end
end
