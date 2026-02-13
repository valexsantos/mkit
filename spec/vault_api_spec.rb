# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Vault API' do
  include Rack::Test::Methods

  def app
    MKIt::Server
  end

  describe 'GET /vault' do
    it 'returns empty array when no secrets' do
      get '/vault'
      assert_equal 200, last_response.status
      assert_equal [], JSON.parse(last_response.body)
    end

    it 'lists all secrets' do
      VaultSecret.create!(scope: 'services', path: 'app/db', key: 'PASSWORD', value: 'secret')
      VaultSecret.create!(scope: 'mkit', path: 'registry', key: 'TOKEN', value: 'token')

      get '/vault'
      assert_equal 200, last_response.status
      secrets = JSON.parse(last_response.body)
      assert_equal 2, secrets.size
    end
  end

  describe 'GET /vault/:scope' do
    it 'filters by scope' do
      VaultSecret.create!(scope: 'services', path: 'app/db', key: 'PASSWORD', value: 'secret')
      VaultSecret.create!(scope: 'mkit', path: 'registry', key: 'TOKEN', value: 'token')

      get '/vault/services'
      assert_equal 200, last_response.status
      secrets = JSON.parse(last_response.body)
      assert_equal 1, secrets.size
      assert_equal 'services', secrets.first['scope']
    end
  end

  describe 'GET /vault/:scope/:path' do
    it 'returns secrets for path' do
      VaultSecret.create!(scope: 'services', path: 'app/db', key: 'PASSWORD', value: 'secret')

      get '/vault/services/app/db'
      assert_equal 200, last_response.status
      secrets = JSON.parse(last_response.body)
      assert_equal 1, secrets.size
    end

    it 'returns 404 for non-existent path' do
      get '/vault/services/non/existent'
      assert_equal 404, last_response.status
    end
  end

  describe 'POST /vault' do
    it 'creates secret' do
      post '/vault', JSON.dump({
                                 scope: 'services',
                                 path: 'new-app/db',
                                 key: 'PASSWORD',
                                 value: 'new-secret'
                               }), 'CONTENT_TYPE' => 'application/json'

      assert_equal 200, last_response.status
      assert VaultSecret.exists?(scope: 'services', path: 'new-app/db', key: 'PASSWORD')
    end

    it 'updates existing secret' do
      VaultSecret.create!(scope: 'services', path: 'app/db', key: 'PASSWORD', value: 'old')

      post '/vault', JSON.dump({
                                 scope: 'services',
                                 path: 'app/db',
                                 key: 'PASSWORD',
                                 value: 'updated'
                               }), 'CONTENT_TYPE' => 'application/json'

      assert_equal 200, last_response.status
      secret = VaultSecret.find_by(scope: 'services', path: 'app/db', key: 'PASSWORD')
      assert_equal 'updated', secret.decrypt_value
    end

    it 'validates required fields' do
      post '/vault', JSON.dump({ scope: 'services' }), 'CONTENT_TYPE' => 'application/json'
      assert_equal 400, last_response.status
    end

    it 'validates scope' do
      post '/vault', JSON.dump({
                                 scope: 'invalid',
                                 path: 'app/db',
                                 key: 'KEY',
                                 value: 'val'
                               }), 'CONTENT_TYPE' => 'application/json'
      assert_equal 400, last_response.status
    end
  end

  describe 'DELETE /vault/:scope/:path/:key' do
    let(:secret) { VaultSecret.create!(scope: 'services', path: 'app/db', key: 'PASSWORD', value: 'secret') }

    it 'deletes secret' do
      delete '/vault/services/app/db/PASSWORD'
      assert_equal 200, last_response.status
      refute VaultSecret.exists?(secret.id)
    end

    it 'returns 404 for non-existent' do
      delete '/vault/services/non/existent'
      assert_equal 404, last_response.status
    end
  end
end
