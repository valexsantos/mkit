require 'mkit/app/helpers/erb_helper'
require 'mkit/app/helpers/docker_helper'
require 'mkit/app/model/service'
require 'mkit/status'

class Pod < ActiveRecord::Base
  belongs_to :service
  has_one    :dns_host, dependent: :destroy

  before_destroy :clean_up

  include MKIt::ERBHelper
  include MKIt::DockerHelper

  def update_ip
    new_ip = nil
    tries = 5
    while (new_ip.nil? && tries > 0) do
      new_ip = self.instance.NetworkSettings.Networks[self.service.pods_network].IPAddress
      sleep(1) if new_ip.nil?
      tries = tries - 1
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

  def set_status_from_docker
    if !self.instance.nil?
      if instance.State.Running
        self.status = MKIt::Status::RUNNING
      else
        self.status = MKIt::Status::STOPPED
      end
    else
      self.status = MKIt::Status::PENDING
    end
    self.save
    self.status
  end

  def parse
    parse_model(MKIt::Templates::DOCKER_RUN).result(binding)
  end

  def start
    start_instance(self.name) unless instance.State.Running
  end

  def stop
    stop_instance(self.name) unless self.instance.nil? || !self.instance.State.Running
  end

  def instance
    properties = inspect_instance(self.name)
    return properties.to_o unless properties.nil?
    nil
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

