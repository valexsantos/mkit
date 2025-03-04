# frozen_string_literal: true
require 'mkit/app/model/backend'
require 'mkit/app/model/frontend'

class Ingress < ActiveRecord::Base
  belongs_to :service
  has_many :frontends, dependent: :destroy
  has_many :backends, dependent: :destroy

  def self.create(yaml)
    validate(yaml)
    ingress = Ingress.new

    yaml["backend"].each do |back|
      ingress.backends << Backend.create(back)
    end

    yaml["frontend"].each do |front|
      ingress.frontends << Frontend.create(front)
    end
    ingress
  end

  def self.validate(yaml)
    frontend_names = []
    frontend_ports = []

    # must have at least one frontend and one backend
    raise "Ingress section is mandatory" unless yaml
    raise "At least one frontend is mandatory" unless yaml["frontend"]
    raise "At least one backend is mandatory" unless yaml["backend"]
    # frontend name is mandatory
    yaml["frontend"].each { |front| raise "Frontend name is mandatory" unless front["name"] }
    # backend name is mandatory
    yaml["backend"].each { |back| raise "Backend name is mandatory" unless back["name"] }
    # frontend must point to a valid backend name - backend names list
    backend_names = yaml["backend"].map { |back| back["name"] }

    # frontend validation
    yaml["frontend"].each do |front|
      # name is mandatory
      raise "Frontend name is mandatory" unless front["name"]
      # frontend name must be unique
      if frontend_names.include?(front["name"])
        raise "Frontend name '#{front["name"]}' must be unique"
      end
      frontend_names << front["name"]

      # bind and mode are mandatory, port is not
      raise "Frontend bind and mode are mandatory" unless front["bind"] && front["bind"]["mode"]

      # port must be unique
      if frontend_ports.include?(front["bind"]["port"])
        raise "Frontend port '#{front["bind"]["port"]}' must be unique"
      end
      frontend_ports << front["bind"]["port"]

      # default_backend must point to a valid backend name
      unless backend_names.include?(front["default_backend"])
        raise "Frontend default_backend '#{front["default_backend"]}' must point to a valid backend name"
      end

    end

    # backend validation
    backend_names.each do |name|
      if backend_names.count(name) > 1
        raise "Backend name '#{name}' must be unique"
      end
    end

    # global validations
    # each backend must point to a valid frontend default_backend
    frontend_default_backends = yaml["frontend"].map { |front| front["default_backend"] }
    yaml["backend"].each do |back|
      unless frontend_default_backends.include?(back["name"])
        raise "Backend '#{back["name"]}' must be referenced by at least one frontend default_backend"
      end
    end

    # when frontend port is range - e.g. 1200-1220, referred backend port must be empty
    yaml["frontend"].each do |front|
      if front["bind"]["port"] =~ /^\d+-\d+$/
        referred_backend = yaml["backend"].find { |back| back["name"] == front["default_backend"] }
        raise "Frontend port range '#{front["bind"]["port"]}' must have an empty backend port" unless referred_backend && (referred_backend["bind"]["port"].nil?)
      end
    end

    true
  end

  def to_h(options = {})
    {
      frontend: self.frontends.map { |front| front.to_h },
      backend: self.backends.map { |back| back.to_h }
    }.remove_symbols_from_keys
  end
end
