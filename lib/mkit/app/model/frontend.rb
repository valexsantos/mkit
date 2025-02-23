# frozen_string_literal: true
require 'mkit/exceptions'

class Frontend  < ActiveRecord::Base
  belongs_to :ingress
  serialize :options, JSON
  serialize :bind_options, JSON
  has_one :backend

  def self.create(yaml)
    validate(yaml)
    frontend = Frontend.new

    frontend.name = yaml["name"]
    frontend.port = yaml["bind"]["port"] if yaml["bind"]["port"]
    frontend.mode = yaml["bind"]["mode"] if yaml["bind"]["mode"]
    frontend.ssl = !yaml["bind"]["ssl"].nil? && yaml["bind"]["ssl"].to_s.start_with?('true') ? 'true':'false'
    frontend.crt = yaml["bind"]["cert"].nil? ? MKIt::Utils.proxy_cert : yaml["bind"]["cert"]
    frontend.bind_options = yaml["bind"]["options"] if yaml["bind"]["options"]
    frontend.options = yaml["options"] if yaml["options"]
    frontend.default_backend = yaml["default_backend"]
    frontend
  end

  def self.validate(yaml)
    raise "name is mandatory" unless yaml["name"]
    raise "default_backend is mandatory" unless yaml["default_backend"]
    raise "bind is mandatory" unless yaml["bind"]
    raise "mode is mandatory" unless yaml["bind"]["mode"]
  end

  def ssl?
    self.ssl == 'true'
  end

  def to_h(options = {})
    {
      name: self.name,
      bind: {
        port: self.port,
        mode: self.mode,
        ssl: self.ssl,
        crt: self.crt,
        options: self.bind_options
      },
      options: self.options,
      default_backend: self.default_backend
    }.remove_symbols_from_keys
  end
end
