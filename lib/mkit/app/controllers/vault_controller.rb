# frozen_string_literal: true

require 'mkit/app/model/vault_secret'

class VaultController < MKIt::Server
  get '/vault' do
    secrets = VaultSecret.all.select(:scope, :path, :key, :ctype)
    secrets.map { |s| { scope: s.scope, path: s.path, key: s.key, ctype: s.ctype } }
  end

  get '/vault/:scope' do
    secrets = VaultSecret.where(scope: params[:scope])
    secrets.map { |s| { path: s.path, key: s.key, ctype: s.ctype } }
  end

  get '/vault/:scope/:path' do
    secrets = VaultSecret.where(scope: params[:scope], path: params[:path])
    secrets.map { |s| { key: s.key, ctype: s.ctype } }
  end

  get '/vault/:scope/:path/:key' do
    secret = VaultSecret.find_by(scope: params[:scope], path: params[:path], key: params[:key])
    unless secret
      raise MKIt::ServiceNotFoundException, "Vault secret not found: #{params[:scope]}/#{params[:path]}##{params[:key]}"
    end

    { scope: secret.scope, path: secret.path, key: secret.key, ctype: secret.ctype }
  end

  post '/vault' do
    payload = JSON.parse(request.body.read)
    raise MKIt::InvalidConfigurationException, 'scope is required' unless payload['scope']
    raise MKIt::InvalidConfigurationException, 'path is required' unless payload['path']
    raise MKIt::InvalidConfigurationException, 'key is required' unless payload['key']
    raise MKIt::InvalidConfigurationException, 'value is required' unless payload['value']

    secret = VaultSecret.find_or_initialize_by(
      scope: payload['scope'],
      path: payload['path'],
      key: payload['key']
    )
    secret.value = payload['value']
    secret.save!
    { scope: secret.scope, path: secret.path, key: secret.key, ctype: secret.ctype }
  end

  put '/vault/:scope/:path/:key' do
    secret = VaultSecret.find_by(scope: params[:scope], path: params[:path], key: params[:key])
    unless secret
      raise MKIt::ServiceNotFoundException, "Vault secret not found: #{params[:scope]}/#{params[:path]}##{params[:key]}"
    end

    payload = JSON.parse(request.body.read)
    secret.value = payload['value'] if payload['value']
    secret.save!
    { scope: secret.scope, path: secret.path, key: secret.key, ctype: secret.ctype }
  end

  delete '/vault/:scope/:path/:key' do
    secret = VaultSecret.find_by(scope: params[:scope], path: params[:path], key: params[:key])
    unless secret
      raise MKIt::ServiceNotFoundException, "Vault secret not found: #{params[:scope]}/#{params[:path]}##{params[:key]}"
    end

    secret.destroy
    { deleted: true }
  end
end
