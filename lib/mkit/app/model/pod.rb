require 'mkit/container/registry'
require 'mkit/container/spec'
require 'mkit/app/model/service'
require 'mkit/status'

class Pod < ActiveRecord::Base
  belongs_to :service
  has_one    :dns_host, dependent: :destroy

  before_destroy :clean_up

  # Updates the pod ip (and its dns) from the container info, publishing pod_ip_updated (which
  # refreshes the proxy config) when it changes. Does not wait.
  #  - container gone (info nil): the ip is cleared, the pod leaves the proxy config
  #  - container exists without ip in the service network (not started, stopped): the last ip is kept,
  #    a stopped pod still counts; the next container event brings the new one
  # The pod is saved before the job is published: the worker reads the ip from the database.
  # notify: false leaves the job to the caller (it must publish it, e.g. once per service)
  def sync_ip(info, notify: true)
    return self.ip if info && info.ip_on(self.service.pods_network).nil?

    new_ip = info&.ip_on(self.service.pods_network)
    return self.ip if new_ip == self.ip

    self.ip = new_ip
    self.save
    new_ip.nil? ? self.clear_dns : self.update_dns
    MkitJob.publish(topic: :pod_ip_updated, service_id: self.service.id, pod_id: self.id) if notify
    MKItLogger.info("pod #{self.name} ip updated [#{self.ip.inspect}]")
    self.ip
  end

  # the dns server cannot answer with an empty address
  def clear_dns
    self.dns_host = nil
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

  # Starts the container; recreates it when it does not exist (e.g. removed with `docker rm`).
  def start
    info = container
    if info.nil?
      MKItLogger.warn("pod #{self.name} has no container, creating it")
      MkitJob.publish(topic: :create_pod_saga, data: { pod_name: self.name })
    elsif !info.running?
      containers.start(self.name)
    end
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

