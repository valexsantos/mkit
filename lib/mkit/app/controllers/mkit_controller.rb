# frozen_string_literal: true

require 'mkit/version'
require 'mkit/metrics/collector'
require 'mkit/backup/manager'

class MkitController < MKIt::Server
  get '/mkit/version' do
    "MKIt Server version #{MKIt::VERSION}\n"
  end

  get '/metrics' do
    content_type 'text/plain'
    MKIt::Metrics::Collector.new.collect
  end

  post '/mkit/backup' do
    payload = begin
                JSON.parse(request.body.read)
    rescue StandardError
                {}
    end
    result = MKIt::Backup::Manager.new.backup(payload['name'])
    format_response(result)
  end

  get '/mkit/backups' do
    backups = MKIt::Backup::Manager.new.list
    format_response(backups)
  end

  post '/mkit/restore' do
    payload = begin
                JSON.parse(request.body.read)
    rescue StandardError
                {}
    end
    return format_response({ success: false, error: 'backup_path required' }) unless payload['backup_path']

    result = MKIt::Backup::Manager.new.restore(payload['backup_path'])
    format_response(result)
  end

  put '/mkit/proxy/restart' do
    MKIt::HAProxy.restart
  end

  put '/mkit/proxy/start' do
    MKIt::HAProxy.start
  end

  put '/mkit/proxy/stop' do
    MKIt::HAProxy.stop
  end

  get '/mkit/proxy/status' do
    MKIt::HAProxy.status
  end
end
