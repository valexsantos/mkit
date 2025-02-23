# frozen_string_literal: true

require 'mkit/utils'

module MKIt
  module MigrationsHelper

    def migrate_service(yaml)
      puts yaml
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
          bind: {
            port: external_port.to_i,
            ssl: ssl.start_with?(':ssl'),
            cert: cert || '/etc/ssl/certs/server.crt'
          },
          mode: mode,
          options: [],
          default_backend: "backend-#{external_port}"
        }

        backend = {
          name: "backend-#{external_port}",
          bind: {
            port: internal_port.to_i,
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

      puts ingress
      ingress.remove_symbols_from_keys
    end

    def remove_symbols_from_keys(hash)
      hash.each_with_object({}) do |(k, v), new_hash|
        new_key = k.to_s
        new_value = if v.is_a?(Hash)
                      remove_symbols_from_keys(v)
                    elsif v.is_a?(Array)
                      v.map { |item| item.is_a?(Hash) ? remove_symbols_from_keys(item) : item }
                    else
                      v
                    end
        new_hash[new_key] = new_value
      end
    end
  end
end
