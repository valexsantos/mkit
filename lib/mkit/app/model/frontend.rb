# frozen_string_literal: true
require 'mkit/exceptions'

class Frontend  < ActiveRecord::Base
  belongs_to :ingress
  serialize :options, coder: JSON
  serialize :bind_options, coder: JSON
  has_one :backend

  def self.create(yaml)
    validate(yaml)
    frontend = Frontend.new

    frontend.name = yaml["name"]
    frontend.port = yaml["bind"]["port"] if yaml["bind"]["port"]
    frontend.mode = yaml["bind"]["mode"] if yaml["bind"]["mode"]
    frontend.bind_options = yaml["bind"]["options"] if yaml["bind"]["options"]
    frontend.options = yaml["options"] if yaml["options"]
    frontend.default_backend = yaml["default_backend"]

    has_ssl = !yaml["bind"]["ssl"].nil? && yaml["bind"]["ssl"].to_s.start_with?('true')
    frontend.ssl = has_ssl ? 'true' : 'false'
    if has_ssl
      frontend.crt = yaml["bind"]["cert"].nil? ? MKIt::Utils.proxy_cert : yaml["bind"]["cert"]
    end

    frontend
  end

  def self.validate(yaml)
    raise_bad_configuration "name is mandatory" unless yaml["name"]
    raise_bad_configuration "default_backend is mandatory" unless yaml["default_backend"]
    raise_bad_configuration "bind is mandatory" unless yaml["bind"]
    raise_bad_configuration "mode is mandatory" unless yaml["bind"]["mode"]
    raise_bad_configuration "frontend port is mandatory" unless yaml["bind"]["port"]
    raise_bad_configuration "mode must match tcp|http" unless yaml["bind"]["mode"] =~ /^(tcp|http)$/
  end

  def ssl?
    self.ssl == 'true'
  end

  def to_h(options = {})
    hash = {
      name: self.name,
      options: self.options,
      bind: {
        port: self.port,
        mode: self.mode,
        ssl: self.ssl,
        cert: self.ssl? ? self.crt : nil,
        options: self.bind_options
      },
      default_backend: self.default_backend
    }

    unless self.ssl?
      hash[:bind].delete(:ssl)
      hash[:bind].delete(:cert)
    end
    hash.remove_symbols_from_keys
  end
end
