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
      resource.min_replicas = (yaml['min_replicas'] || 1)
      resource.max_replicas = (yaml['max_replicas'] || resource.min_replicas)
      resource.cpu_limits = yaml['limits']['cpu'] if yaml['limits'] && yaml['limits']['cpu']
      resource.memory_limits = yaml['limits']['memory'] if yaml['limits'] && yaml['limits']['memory']
      resource.memory_swap_limits = yaml['limits']['memory_swap'] if yaml['limits'] && yaml['limits']['memory_swap']
      if yaml['scaling'] && yaml['scaling']['target_cpu_percent']
        resource.target_cpu_percent = yaml['scaling']['target_cpu_percent']
      end
      if yaml['scaling'] && yaml['scaling']['target_memory_percent']
        resource.target_memory_percent = yaml['scaling']['target_memory_percent']
      end
      resource.scale_up_stabilization = yaml['scaling']['scale_up_stabilization_seconds'] || 0
      resource.scale_down_stabilization = yaml['scaling']['scale_down_stabilization_seconds'] || 0
    end
    resource
  end

  def self.validate(yaml)
    unless yaml.nil?
      if yaml['min_replicas'] && yaml['min_replicas'] < 1
        raise_bad_configuration 'resource min_replicas must be bigger or equal than 1'
      end
      if yaml['max_replicas'] && yaml['max_replicas'] < 1
        raise_bad_configuration 'resource max_replicas must be bigger or equal than 1'
      end
      if yaml['min_replicas'] && yaml['max_replicas'] && (yaml['min_replicas'] > yaml['max_replicas'])
          raise_bad_configuration 'resource max_replicas must be bigger or equal than min_replicas'
      end
    end
    # validate limits
    unless yaml.nil? || yaml['limits'].nil?
      resources = yaml['limits']
      if resources['cpu'] && resources['cpu'] !~ /\d+m$/
        raise_bad_configuration "resource cpu limits must match '\\d+m'"
      end
      if resources['memory'] && resources['memory'] !~ /\d+m$/
        raise_bad_configuration "resource memory limits must match '\\d+m'"
      end
      if resources['memory_swap'] && resources['memory_swap'] !~ /\d+m$/
        raise_bad_configuration "resource memory_swap limits must match '\\d+m'"
      end
    end
    true
  end

  def to_h(_options = {})
    hash = {
      min_replicas: min_replicas,
      max_replicas: max_replicas
    }
    if cpu_limits || memory_limits || memory_swap_limits
      hash[:limits] = {}
      hash[:limits][:cpu] = cpu_limits if cpu_limits
      hash[:limits][:memory] = memory_limits if memory_limits
      hash[:limits][:memory_swap] = memory_swap_limits if memory_swap_limits
    end
    if target_cpu_percent || target_memory_percent
      hash[:scaling] = {}
      hash[:scaling][:target_cpu_percent] = target_cpu_percent if target_cpu_percent
      hash[:scaling][:target_memory_percent] = target_memory_percent if target_memory_percent
      hash[:scaling][:scale_up_stabilization_seconds] = scale_up_stabilization if scale_up_stabilization&.positive?
      if scale_down_stabilization&.positive?
        hash[:scaling][:scale_down_stabilization_seconds] =
          scale_down_stabilization
      end
    end
    hash.remove_symbols_from_keys
  end
end
