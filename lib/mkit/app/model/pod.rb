require 'mkit/container/registry'
require 'mkit/container/spec'
require 'mkit/app/model/service'
require 'mkit/status'

class Pod < ActiveRecord::Base
  belongs_to :service
  has_one    :dns_host, dependent: :destroy

  before_destroy :clean_up

  IP_TRIES = 5

  def update_ip
    new_ip = nil
    tries = IP_TRIES
    while new_ip.nil? && tries > 0
      new_ip = container&.ip_on(self.service.pods_network)
      sleep(1) if new_ip.nil?
      tries -= 1
    end
    if self.ip != new_ip
      self.ip = new_ip
      self.update_dns
      MkitJob.publish(topic: :pod_ip_updated, service_id: self.service.id, pod_id: self.id)
    end
    MKItLogger.info("docker ip updated [#{self.ip}]")
    self.ip
  end

  def update_dns
    self.dns_host ||= DnsHost.new(
      service: self.service,
      name:    "#{self.service.name}.internal",
      ip:      self.ip
    )
    self.dns_host.ip = self.ip
    self.dns_host.save
  end

  def set_status_from_container
    info = container
    self.status = if info.nil?
                    MKIt::Status::PENDING
                  elsif info.running?
                    MKIt::Status::RUNNING
                  else
                    MKIt::Status::STOPPED
                  end
    self.save
    self.status
  end

  def container_spec
    MKIt::Container::Spec.new(name: self.name, service: self.service)
  end

  def start
    containers.start(self.name) unless container&.running?
  end

  def stop
    containers.stop(self.name) if container&.running?
  end

  # MKIt::Container::Info of the pod's container, nil when it does not exist
  def container
    containers.find(self.name)
  end

  def containers
    MKIt::Container::Registry.api.containers
  end

  def clean_up
    # stop and destroy pod
    MkitJob.publish(topic: :destroy_pod_saga,
                    service_id: self.service.id,
                    pod_id: self.id,
                    data: {pod_name: self.name}
    )
  end

  def to_h
    {
      'name' => self.name,
      'ip' => self.dns_host.nil? || self.dns_host.ip.nil? ? self.ip : self.dns_host.ip,
      'dns' => self.dns_host.nil? || self.dns_host.name.nil? ? self.ip : self.dns_host.name,
      'status' => self.status
    }
  end
end

