# frozen_string_literal: true

require_relative 'spec_helper'

describe Service do
  let(:service_yaml) do
    {
      'service' => {
        'name' => 'test-service',
        'image' => 'nginx:latest',
        'network' => 'bridge'
      }
    }
  end

  let(:service_with_vault) do
    {
      'service' => {
        'name' => 'test-vault-service',
        'image' => 'nginx:latest',
        'environment' => {
          'DB_PASSWORD' => 'vault:/services/test-vault-service/db#PASSWORD'
        }
      }
    }
  end

  describe 'vault validation' do
    it 'passes when vault reference is valid' do
      VaultSecret.create!(
        scope: 'services',
        path: 'test-vault-service/db',
        key: 'PASSWORD',
        value: 'secret'
      )

      service = Service.new(name: 'test-vault-service', image: 'nginx:latest')
      service.service_config = [
        ServiceConfig.new(key: 'DB_PASSWORD', value: 'vault:/services/test-vault-service/db#PASSWORD',
                          ctype: 'environment')
      ]

      errors = service.validate_vault!
      assert_empty errors
    end

    it 'fails when vault reference is missing' do
      service = Service.new(name: 'test-service', image: 'nginx:latest')
      service.service_config = [
        ServiceConfig.new(key: 'DB_PASSWORD', value: 'vault:/services/test-service/db#PASSWORD', ctype: 'environment')
      ]

      errors = service.validate_vault!
      assert_equal 1, errors.size
      assert_match(/not found/, errors.first)
    end

    it 'passes when no vault references' do
      service = Service.new(name: 'test-plain', image: 'nginx:latest')
      service.service_config = [
        ServiceConfig.new(key: 'DEBUG', value: 'true', ctype: 'environment')
      ]

      errors = service.validate_vault!
      assert_empty errors
    end
  end

  describe 'service_mesh_config' do
    let(:service_with_mesh) do
      Service.new(
        name: 'mesh-service',
        image: 'nginx:latest',
        service_mesh: {
          'mtls' => { 'enabled' => true },
          'circuit_breaker' => { 'enabled' => true, 'max_failures' => 3 }
        }.to_json
      )
    end

    it 'parses service mesh config' do
      config = service_with_mesh.service_mesh_config
      assert config
      assert config['mtls']['enabled']
      assert config['circuit_breaker']['enabled']
      assert_equal 3, config['circuit_breaker']['max_failures']
    end

    it 'returns nil when no service mesh' do
      service = Service.new(name: 'no-mesh', image: 'nginx:latest')
      assert_nil service.service_mesh_config
    end
  end
end
