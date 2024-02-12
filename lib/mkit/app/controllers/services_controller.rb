# frozen_string_literal: true

require 'mkit/app/model/service'
require 'mkit/app/helpers/services_helper'

class ServicesController < MKIt::Server
  helpers MKIt::ServicesHelper

  # curl localhost:4567/services
  get '/services' do
    verbose = params[:verbose] == 'true'

    if params[:id]
      redirect "/services/#{params[:id]}"
    elsif params[:name]
      srv = find_by_id_or_name
      format_response(srv, verbose)
    else
      services = Service.all
      format_response(services, verbose)
    end
  end

  get '/services/:id' do
    srv = find_by_id_or_name
    resp = if request.env['CONTENT_TYPE'] == 'application/json'
             srv.to_json
           else
             format_response(srv)
           end
    resp
  end

  get '/services/:id/logs' do
    srv = find_by_id_or_name
    srv.log
  end

  # curl -X PUT localhost:4567/services/1  -F "file=@mkit/samples/mkit.yml"
  put '/services/:id' do
    srv = find_by_id_or_name
    if params[:file]
      tempfile = params[:file][:tempfile]
      yaml = YAML.safe_load(tempfile.read)
      srv.update!(yaml.to_o)
    end
    format_response(srv)
  end

  # curl -X DELETE localhost:4567/services/1
  delete '/services/:id' do
    srv = find_by_id_or_name
    MkitJob.publish(topic: :delete_service, service_id: srv.id)
    format_response(srv)
  end

  # curl -X POST localhost:4567/services  -F "file=@mkit/samples/mkit.yml"
  post '/services' do
    srv = 'no file'
    if params[:file]
      tempfile = params[:file][:tempfile]
      yaml = YAML.safe_load(tempfile.read)
      srv = Service.create(yaml.to_o)
    end
    format_response(srv)
  end

  #
  # operations
  #
  # curl -X PUT localhost:4567/services/1/start
  put '/services/:id/start' do
    srv = find_by_id_or_name
    MkitJob.publish(topic: :start_service, service_id: srv.id)
    format_response(srv)
  end

  # curl -X PUT localhost:4567/services/1/stop
  put '/services/:id/stop' do
    srv = find_by_id_or_name
    MkitJob.publish(topic: :stop_service, service_id: srv.id)
    format_response(srv)
  end

  put '/services/:id/restart' do
    srv = find_by_id_or_name
    MkitJob.publish(topic: :stop_service, service_id: srv.id)
    MkitJob.publish(topic: :start_service, service_id: srv.id)
    format_response(srv)
  end
end
