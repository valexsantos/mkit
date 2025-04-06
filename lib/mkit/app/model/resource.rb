# frozen_string_literal: true

class Resource < ActiveRecord::Base
  belongs_to :service

  def self.create(yaml)
    resource = Resource.new
    if yaml.nil?
      resource.max_replicas = 1
      resource.min_replicas = 1
    else
      validate(yaml)
      if yaml["min_replicas"]
        resource.min_replicas = yaml["min_replicas"]
      else
        resource.min_replicas = 1
      end
      if yaml["max_replicas"]
        resource.max_replicas = yaml["max_replicas"]
      else
        resource.max_replicas = resource.min_replicas
      end
      resource.cpu_limits = yaml["limits"]["cpu"] if yaml["limits"] && yaml["limits"]["cpu"]
      resource.memory_limits = yaml["limits"]["memory"] if yaml["limits"] && yaml["limits"]["memory"]
      resource.memory_swap_limits = yaml["limits"]["memory_swap"] if yaml["limits"] && yaml["limits"]["memory_swap"]
    end
    resource
  end

  def self.validate(yaml)
    unless yaml.nil?
      raise_bad_configuration "resource min_replicas must be bigger or equal than 1" if yaml["min_replicas"] && yaml["min_replicas"] < 1
      raise_bad_configuration "resource max_replicas must be bigger or equal than 1" if yaml["max_replicas"] && yaml["max_replicas"] < 1
      if yaml["min_replicas"] && yaml["max_replicas"]
        raise_bad_configuration "resource max_replicas must be bigger or equal than min_replicas" if yaml["min_replicas"] > yaml["max_replicas"]
      end
    end
    # validate limits
    unless yaml.nil? || yaml["limits"].nil?
      resources = yaml["limits"]
      raise_bad_configuration "resource cpu limits must match '\\d+m'" if resources["cpu"] && resources["cpu"] !~ /\d+m$/
      raise_bad_configuration "resource memory limits must match '\\d+m'" if resources["memory"] && resources["memory"] !~ /\d+m$/
      raise_bad_configuration "resource memory_swap limits must match '\\d+m'" if resources["memory_swap"] && resources["memory_swap"] !~ /\d+m$/
    end
    true
  end

  def to_h(options = {})
    hash = {
      min_replicas: self.min_replicas,
      max_replicas: self.max_replicas
    }
    if self.cpu_limits || self.memory_limits || self.memory_swap_limits
      hash[:limits] = {}
      hash[:limits][:cpu] = self.cpu_limits if self.cpu_limits
      hash[:limits][:memory] = self.memory_limits if self.memory_limits
      hash[:limits][:memory_swap] = self.memory_swap_limits if self.memory_swap_limits
    end
    hash.remove_symbols_from_keys
  end
end
