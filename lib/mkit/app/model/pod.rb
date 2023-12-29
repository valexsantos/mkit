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
        instance = self.properties.to_o
        new_ip = instance.NetworkSettings.Networks[self.service.pods_network].IPAddress
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
      name:    "#{name}.#{self.service.name}",
      ip:      self.ip
    )
    self.dns_host.ip = self.ip
    self.dns_host.save
  end

  def properties
    inspect_instance(self.name)
  end

  def set_status_from_docker
    instance = self.properties
    if self.properties
      instance = instance.to_o
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
    if self.pod_id.nil?
      docker_run = parse
      MKItLogger.info("deploying docker pod, cmd [#{docker_run}]")
      create_instance(docker_run)
    else
      pre_check

      instance = self.properties.to_o
      start_instance(self.name) unless instance.State.Running
    end
  end

  def stop
    pre_check
    stop_instance(self.name)
  end

  def pre_check
    raise MKIt::PodNotFoundException.new('no pod_name found') if self.name.nil?
    raise MKIt::PodNotFoundException.new("no properties found for #{self.name}") if self.properties.nil?
  end

  def clean_up
    remove_instance(self.name) unless self.pod_id.nil?
    MkitJob.publish(topic: :pod_destroyed, service_id: self.service.id, data: {pod_id: self.id})
  end
end

