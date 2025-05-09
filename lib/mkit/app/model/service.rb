require 'mkit/app/model/volume'
require 'mkit/app/model/ingress'
require 'mkit/app/model/resource'
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
require 'mkit/app/model/dns_host'
require 'mkit/app/helpers/haproxy'

#
class Service < ActiveRecord::Base
  has_many   :pod, dependent: :destroy
  has_many   :volume, dependent: :destroy
  has_many   :service_config, dependent: :destroy
  has_many   :service_port, dependent: :destroy

  has_one  :lease, dependent: :destroy
  has_one  :dns_host, dependent: :destroy
  has_one  :ingress, dependent: :destroy
  has_one  :resource, dependent: :destroy

  before_destroy :clean_up

  validates :name, uniqueness: true
  validates :name, presence: true

  include MKIt::ERBHelper
  include MKIt::DockerHelper

  def self.create(yaml)
    config = yaml["service"]
    raise MKIt::ServiceAlreadyExists.new unless Service.find_by_name(config.name).nil?

    ActiveRecord::Base.transaction do
      srv = Service.new(
        name: config.name,
        version: 1,
        image: config.image,
        command: config.command,
        status: MKIt::Status::CREATING
      )

      # reserve pool ip
      srv.lease = Pool.find_by_name(MKIt::Utils.me).reserve_for(srv)

      srv.dns_host = DnsHost.new(
        service: srv,
        name: srv.name,
        ip: srv.lease.ip
      )

      # create service network
      srv.deploy_network

      # configure
      srv.configure(config)
      #
      srv.status = MKIt::Status::CREATED
      srv.save!
      data = { service_id: srv.id, version: srv.version }
      # create pod
      (1..srv.resource.min_replicas).each { |i|
        pd = Pod.new( status: MKIt::Status::CREATED, name: SecureRandom.uuid.gsub('-','')[0..11])
        srv.pod << pd
        MkitJob.publish(topic: :create_pod_saga, data: {pod_name: pd.name})
      }
      srv
    end
  end

  def configure(config)
    self.image = config.image if config.image != self.image
    self.command = config.command if config.command != self.command

    self.resource = Resource.create(config.resources)

    # docker network
    if config.network.nil? || config.network.empty?
      self.pods_network="mkit"
    else
      self.pods_network=config.network
    end
    self.create_pods_network

    # haproxy config
    self.ingress = Ingress.create(config.ingress)

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
    ActiveRecord::Base.transaction do
      config = yaml["service"]
      raise MKIt::ServiceNameMismatch.new unless config.name == self.name
      self.version+=1
      self.configure(config)

      # destroy old pods...
      self.pod.destroy_all
      # create pod
      (1..self.resource.min_replicas).each { |i|
        pd = Pod.new( status: MKIt::Status::CREATED, name: SecureRandom.uuid.gsub('-','')[0..11])
        self.pod << pd
        MkitJob.publish(topic: :create_pod_saga, data: {pod_name: pd.name})
      }
      self.save
    end
  end

  def create_pods_network
    create_network(self.pods_network) unless network_exists?(self.pods_network)
  end

  def deploy_network
    # create service interface...
    self.lease.confirm
    self.lease.up
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

  # TODO
  #  refactor to remove it from db model and check if it is needed
  #  this will be the pod status
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

  def find_pod_by_id_or_name(pod_id)
    pod = self.pod.find_by(id: pod_id)
    pod = self.pod.find_by(name: pod_id) unless pod
    pod
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

  def log
    out = ""
    self.pod.each { |p|
      out << "<<<< %s | %s >>>>\n" % [self.name, p.name]
      out << logs(p.name)
    }
    out
  end
  def to_h(options = {})
    details = options[:details] || false

    yaml = {}
    yaml['service'] = {}
    srv = yaml['service']
    srv['name'] = self.name
    srv['image'] = self.image
    srv['command'] = self.command
    srv['network'] = self.pods_network
    if details
      srv['status'] = self.status
      srv['version'] = self.version
      srv['ip'] = self.lease.ip
      srv['dns'] = self.dns_host.name
      srv['pods'] = []
      self.pod.each { |p|
        srv['pods'] << p.to_h
      }
    end

    srv['ingress'] = self.ingress.to_h(options)
    srv['resources'] = self.resource.to_h

    srv['volumes'] = []
    self.volume.each { |v|
      if v.ctype ==  MKIt::CType::DOCKER_STORAGE.to_s
        srv['volumes'] << "docker://#{v.name}:#{v.path}"
      elsif v.ctype ==  MKIt::CType::LOCAL_STORAGE.to_s
        srv['volumes'] << "#{v.name}:#{v.path}"
      end
    }
    srv['environment'] = {}
    self.service_config.each { |c|
      srv['environment'][c.key] = "#{c.value}"
    }
    yaml
  end

  def as_json(options = {})
    srv = super
    a=[:pod, :volume, :service_config, :ingress]
    a.each { | k | 
      srv[k] ||= []
      self.send(k).each { |v| 
        srv[k] << v.as_json
      }
    }
    srv
  end
end
