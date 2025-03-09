# frozen_string_literal: true

class MigrateSchema < ActiveRecord::Migration[5.1]

  #
  # migrate the schema from service_ports to ingress
  #
  def up
    Service.all.each do |service|
      ingress_config = service_ports_to_ingress service.service_port
      service.ingress = Ingress.create(ingress_config)
      service.service_port.destroy_all
    end
  end

  def service_ports_to_ingress(ports)
    ingress = { frontend: [], backend: [] }

    ports.each do |port|
      frontend = {
        name: "frontend-#{port.external_port}",
        bind: {
          port: port.external_port,
          mode: port.mode
        },
        options: [],
        default_backend: "backend-#{port.external_port}"
      }

      if !port.ssl.nil? && port.ssl.start_with?('true')
        frontend[:bind][:ssl] = true
        frontend[:bind][:cert] = port.crt
      end

      backend = {
        name: "backend-#{port.external_port}",
        bind: {
          port: port.internal_port,
          mode: port.mode
        },
        balance: port.load_bal
      }

      if port.mode == 'http'
        a= [
          'option httpclose',
          'option forwardfor',
          'cookie JSESSIONID prefix'
        ]
        backend[:options] = a
        backend[:bind][:options] = [ 'cookie A check' ]
      end
      ingress[:frontend] << frontend
      ingress[:backend] << backend
    end

    ingress.remove_symbols_from_keys
  end
end