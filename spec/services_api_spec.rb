# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Services API' do
  include Rack::Test::Methods

  def app
    MKIt::Server
  end

  describe 'GET /services' do
    it 'returns empty array when no services' do
      get '/services'
      assert_equal 200, last_response.status
      assert_equal [], JSON.parse(last_response.body)
    end

    it 'returns services list' do
      Service.create(name: 'test-service', image: 'nginx:latest')
      get '/services'
      assert_equal 200, last_response.status
      services = JSON.parse(last_response.body)
      assert_equal 1, services.size
      assert_equal 'test-service', services.first['name']
    end
  end

  describe 'GET /services/:id' do
    let(:service) { Service.create(name: 'get-test', image: 'nginx:latest') }

    it 'returns service by id' do
      get "/services/#{service.id}"
      assert_equal 200, last_response.status
      data = JSON.parse(last_response.body)
      assert_equal 'get-test', data['name']
    end

    it 'returns service by name' do
      get '/services/get-test'
      assert_equal 200, last_response.status
      data = JSON.parse(last_response.body)
      assert_equal 'get-test', data['name']
    end

    it 'returns 404 for non-existent service' do
      get '/services/non-existent'
      assert_equal 404, last_response.status
    end

    it 'includes details when requested' do
      get "/services/#{service.id}?details=true"
      assert_equal 200, last_response.status
      data = JSON.parse(last_response.body)
      assert data['pods']
    end

    it 'includes errors when requested' do
      service.update(validation_errors: 'Vault secret not found')
      get "/services/#{service.id}?errors=true"
      assert_equal 200, last_response.status
      data = JSON.parse(last_response.body)
      assert data['errors']
    end
  end

  describe 'POST /services' do
    let(:valid_yaml) do
      <<~YAML
        service:
          name: new-service
          image: nginx:latest
          network: bridge
      YAML
    end

    let(:invalid_yaml) do
      <<~YAML
        service:
          name: ""
          image: ""
      YAML
    end

    it 'creates service with valid YAML' do
      post '/services', file: StringIO.new(valid_yaml), 'CONTENT_TYPE' => 'multipart/form-data'
      assert_equal 200, last_response.status
      assert Service.exists?(name: 'new-service')
    end

    it 'validates YAML schema' do
      post '/services', file: StringIO.new(invalid_yaml), 'CONTENT_TYPE' => 'multipart/form-data'
      assert_equal 400, last_response.status
    end

    it 'validates vault references' do
      yaml_with_vault = <<~YAML
        service:
          name: vault-test
          image: nginx:latest
          environment:
            DB_PASSWORD: vault:/services/vault-test/db#PASSWORD
      YAML
      post '/services', file: StringIO.new(yaml_with_vault), 'CONTENT_TYPE' => 'multipart/form-data'
      assert_equal 400, last_response.status
      assert_match(/Vault secret not found/, last_response.body)
    end

    it 'creates service with valid vault reference' do
      VaultSecret.create!(scope: 'services', path: 'vault-test/db', key: 'PASSWORD', value: 'secret')
      yaml_with_vault = <<~YAML
        service:
          name: vault-test
          image: nginx:latest
          environment:
            DB_PASSWORD: vault:/services/vault-test/db#PASSWORD
      YAML
      post '/services', file: StringIO.new(yaml_with_vault), 'CONTENT_TYPE' => 'multipart/form-data'
      assert_equal 200, last_response.status
    end
  end

  describe 'PUT /services/:id' do
    let(:service) { Service.create(name: 'update-test', image: 'nginx:latest') }

    it 'updates service' do
      updated_yaml = <<~YAML
        service:
          name: update-test
          image: nginx:alpine
      YAML
      put "/services/#{service.id}", file: StringIO.new(updated_yaml), 'CONTENT_TYPE' => 'multipart/form-data'
      assert_equal 200, last_response.status
      service.reload
      assert_equal 'nginx:alpine', service.image
    end

    it 'validates vault references on update' do
      updated_yaml = <<~YAML
        service:
          name: update-test
          image: nginx:latest
          environment:
            DB_PASSWORD: vault:/services/update-test/db#PASSWORD
      YAML
      put "/services/#{service.id}", file: StringIO.new(updated_yaml), 'CONTENT_TYPE' => 'multipart/form-data'
      assert_equal 400, last_response.status
      assert_match(/Vault secret not found/, last_response.body)
    end
  end

  describe 'DELETE /services/:id' do
    let(:service) { Service.create(name: 'delete-test', image: 'nginx:latest') }

    it 'deletes service' do
      delete "/services/#{service.id}"
      assert_equal 200, last_response.status
      refute Service.exists?(service.id)
    end

    it 'returns 404 for non-existent' do
      delete '/services/non-existent'
      assert_equal 404, last_response.status
    end
  end

  describe 'Service operations' do
    let(:service) { Service.create(name: 'op-test', image: 'nginx:latest', status: MKIt::Status::CREATED) }

    describe 'START' do
      it 'starts service' do
        put "/services/#{service.id}/start"
        assert_equal 200, last_response.status
      end
    end

    describe 'STOP' do
      it 'stops service' do
        put "/services/#{service.id}/stop"
        assert_equal 200, last_response.status
      end
    end

    describe 'RESTART' do
      it 'restarts service' do
        put "/services/#{service.id}/restart"
        assert_equal 200, last_response.status
      end
    end

    describe 'SCALE' do
      it 'scales service to specified replicas' do
        put "/services/#{service.id}/scale?replicas=5"
        assert_equal 200, last_response.status
      end

      it 'rejects invalid replica count' do
        put "/services/#{service.id}/scale?replicas=0"
        assert_equal 400, last_response.status
      end
    end
  end
end
