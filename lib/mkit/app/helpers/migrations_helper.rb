# frozen_string_literal: true

require 'mkit/utils'

module MKIt
  module MigrationsHelper

    def migrate_service(yaml)
      yaml['service']['ingress'] = ports_to_ingress(yaml['service']['ports'])
      yaml['service'].delete('ports')
      yaml
    end

    def ports_to_ingress(ports)
      ingress = { frontend: [], backend: [] }

      ports.each_with_index do |port_config, index|
        match = port_config.match(/^(.*?):(.*?):(tcp|http):(.*?)($|:ssl$|:ssl,(.+))$/)
        next unless match

        external_port, internal_port, mode, load_bal, ssl, cert = match.captures

        frontend = {
          name: "frontend-#{external_port}",
          options: [],
          bind: {
            port: external_port,
            mode: mode
          },
          default_backend: "backend-#{external_port}"
        }

        if ssl.start_with?(':ssl')
          frontend[:bind][:ssl] = true
          frontend[:bind][:cert] = cert
        end

        backend = {
          name: "backend-#{external_port}",
          bind: {
            port: internal_port,
            mode: mode
          },
          balance: load_bal
        }

        if mode == 'http'
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
end
