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
require 'mkit/app/model/vault_secret'

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
    config = yaml['service']
    raise MKIt::ServiceAlreadyExists unless Service.find_by_name(config.name).nil?

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
      srv.status = MKIt::Status::CREATED
      srv.save!
      data = { service_id: srv.id, version: srv.version }
      # create pod
      (1..srv.resource.min_replicas).each do |_i|
        pd = Pod.new(status: MKIt::Status::CREATED, name: SecureRandom.uuid.gsub('-', '')[0..11])
        srv.pod << pd
        MkitJob.publish(topic: :create_pod_saga, data: { pod_name: pd.name })
      end
      srv
    end
  end

  def configure(config)
    self.image = config.image if config.image != image
    self.command = config.command if config.command != command

    self.resource = Resource.create(config.resources)

    # docker network
    self.pods_network = if config.network.nil? || config.network.empty?
                          'mkit'
                        else
                          config.network
                        end
    create_pods_network

    # haproxy config
    self.ingress = Ingress.create(config.ingress)

    # probes
    self.liveness_probe = config.liveness_probe&.to_h&.to_json
    self.readiness_probe = config.readiness_probe&.to_h&.to_json

    # volumes
    self.volume = []
    config.volumes&.each do |volume|
      add_volume(volume)
    end
    # environment
    self.service_config = []
    config.environment&.each_pair do |key, value|
      add_service_config(key, value)
    end
    self.volume.each do |volume|
      volume.deploy
    end
  end

  def update!(yaml)
    ActiveRecord::Base.transaction do
      config = yaml['service']
      raise MKIt::ServiceNameMismatch unless config.name == name

      self.version += 1
      configure(config)

      # destroy old pods...
      pod.destroy_all
      # create pod
      (1..resource.min_replicas).each do |_i|
        pd = Pod.new(status: MKIt::Status::CREATED, name: SecureRandom.uuid.gsub('-', '')[0..11])
        pod << pd
        MkitJob.publish(topic: :create_pod_saga, data: { pod_name: pd.name })
      end
      save
    end
  end

  def create_pods_network
    create_network(pods_network) unless network_exists?(pods_network)
  end

  def deploy_network
    # create service interface...
    lease.confirm
    lease.up
  end

  def add_volume(volume_config)
    v = Volume.create(self, volume_config)
    volume << v
    v
  end

  def add_service_config(key, value)
    v = ServiceConfig.create(service: self, key: key, value: value)
    service_config << v
    v
  end

  def current_configs
    service_config&.select { |x| x.ctype == MKIt::CType::ENVIRONMENT.to_s && x.version == self.version }
  end

  def current_ports
    service_port&.select { |x| x.version == self.version }
  end

  def liveness_probe_config
    return nil unless liveness_probe

    @liveness_probe_config ||= JSON.parse(liveness_probe)
  end

  def readiness_probe_config
    return nil unless readiness_probe

    @readiness_probe_config ||= JSON.parse(readiness_probe)
  end

  def my_dns
    MKIt::Interface.ip
  end

  # TODO
  #  refactor to remove it from db model and check if it is needed
  #  this will be the pod status
  def update_status!
    combined_status = nil
    pod.each do |pod|
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
    end
    combined_status ||= MKIt::Status::CREATING
    self.status = combined_status
    save
    status
  end

  #
  # ha proxy configs & template
  #
  def update_proxy
    MkitJob.publish(topic: :update_proxy_config, application_id: id, data: proxy_config)
  end

  def proxy_config
    # config
    haproxy = parse
    my_addr = lease.ip.split('.')[3]
    filename = "#{format('%04i', my_addr.to_i)}_#{name}.cfg"
    MKItLogger.debug("haproxy config file: #{filename}")
    { filename: filename, data: haproxy }
  end

  def parse
    parse_model(MKIt::Templates::HAPROXY).result(binding)
  end

  def clean_up
    my_addr = lease.ip.split('.')[3]
    filename = "#{format('%04i', my_addr.to_i)}_#{name}.cfg"
    MkitJob.publish(topic: :destroy_proxy_config, data: { filename: filename })
  end

  def find_pod_by_id_or_name(pod_id)
    pod = self.pod.find_by(id: pod_id)
    pod ||= self.pod.find_by(name: pod_id)
    pod
  end

  #
  # ctrl
  #
  def start
    pod.each do |p|
      MkitJob.publish(topic: :start_pod, service_id: id, pod_id: p.id)
    end
  end

  def stop
    pod.each do |p|
      MkitJob.publish(topic: :stop_pod, service_id: id, pod_id: p.id)
    end
  end

  def log
    out = ''
    pod.each do |p|
      out << format("<<<< %s | %s >>>>\n", name, p.name)
      out << logs(p.name)
    end
    out
  end

  def to_h(options = {})
    details = options[:details] || false
    show_errors = options[:errors] || false

    yaml = {}
    yaml['service'] = {}
    srv = yaml['service']
    srv['name'] = name
    srv['image'] = image
    srv['command'] = command
    srv['network'] = pods_network
    if details
      srv['status'] = status
      srv['version'] = self.version
      srv['ip'] = lease.ip
      srv['dns'] = dns_host.name
      srv['pods'] = []
      pod.each do |p|
        srv['pods'] << p.to_h
      end
    end

    srv['errors'] = validation_errors_list if show_errors && validation_errors_list.any?

    srv['ingress'] = ingress.to_h(options)
    srv['resources'] = resource.to_h

    srv['volumes'] = []
    volume.each do |v|
      if v.ctype == MKIt::CType::DOCKER_STORAGE.to_s
        srv['volumes'] << "docker://#{v.name}:#{v.path}"
      elsif v.ctype == MKIt::CType::LOCAL_STORAGE.to_s
        srv['volumes'] << "#{v.name}:#{v.path}"
      end
    end
    srv['environment'] = {}
    service_config.each do |c|
      srv['environment'][c.key] = "#{c.value}"
    end
    yaml
  end

  def as_json(options = {})
    srv = super
    a = %i[pod volume service_config ingress]
    a.each do |k|
      srv[k] ||= []
      send(k).each do |v|
        srv[k] << v.as_json
      end
    end
    srv
  end

  def validate_vault!
    errors = []
    return errors unless service_config

    service_config.select { |x| x.ctype == MKIt::CType::ENVIRONMENT.to_s }.each do |config|
      next unless config.value.to_s.start_with?('vault://')

      validation = VaultSecret.validate_path(config.value)
      errors << validation[:error] unless validation[:valid]
    end

    if errors.any?
      self.validation_errors = errors.join('; ')
      save
    else
      self.validation_errors = nil
      save
    end
    errors
  end

  def validation_errors_list
    return [] if validation_errors.nil? || validation_errors.empty?

    validation_errors.split('; ')
  end
end
