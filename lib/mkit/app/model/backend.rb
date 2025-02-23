# frozen_string_literal: true

class Backend  < ActiveRecord::Base
  belongs_to :ingress
  serialize :options, JSON
  serialize :bind_options, JSON

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
    raise "name is mandatory" unless yaml["name"]
    raise "bind is mandatory" unless yaml["bind"]
    raise "mode is mandatory" unless yaml["bind"]["mode"]
  end

  def load_balance
    case self.load_bal
    when /^round_robin$/
      "roundrobin"
    when /^leastconn$/
      "leastconn"
    else
      "roundrobin"
    end
  end

  def to_h(options = {})
    {
      name: self.name,
      bind: {
        port: self.port,
        mode: self.mode,
        options: self.bind_options
      },
      options: self.options,
      balance: self.load_bal
    }.remove_symbols_from_keys
  end
end
