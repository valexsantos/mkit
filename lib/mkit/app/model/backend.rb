# frozen_string_literal: true

class Backend  < ActiveRecord::Base
  belongs_to :ingress
  serialize :options, coder: JSON
  serialize :bind_options, coder: JSON

  def self.create(yaml)
    validate(yaml)
    backend = Backend.new
    backend.name = yaml["name"]
    backend.port = yaml["bind"]["port"] if yaml["bind"]["port"]
    backend.mode = yaml["bind"]["mode"] if yaml["bind"]["mode"]
    backend.options = yaml["options"] if yaml["options"]
    backend.load_bal = yaml["balance"] if yaml["balance"]
    backend.bind_options = yaml["bind"]["options"] if yaml["bind"]["options"]
    backend
  end

  def self.validate(yaml)
    raise_bad_configuration "name is mandatory" unless yaml["name"]
    raise_bad_configuration "bind is mandatory" unless yaml["bind"]
    raise_bad_configuration "mode is mandatory" unless yaml["bind"]["mode"]
    raise_bad_configuration "mode must match tcp|http" unless yaml["bind"]["mode"] =~ /^(tcp|http)$/
    if yaml["balance"]
      raise_bad_configuration "balance must match round_robin|least_conn" unless yaml["balance"] =~ /^(round_robin|least_conn)$/
    end
  end

  def load_balance
    case self.load_bal
    when /^round_robin$/
      "roundrobin"
    when /^least_conn$/
      "leastconn"
    else
      "roundrobin"
    end
  end

  def to_h(options = {})
    hash = {
      name: self.name,
      balance: self.load_bal,
      options: self.options,
      bind: {
        port: self.port,
        mode: self.mode,
        options: self.bind_options
      }
    }

    if self.port.nil? || self.port.empty?
      hash[:bind].delete(:port)
    end
    hash.remove_symbols_from_keys
  end
end
