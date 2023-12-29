require 'mkit/app/model/service'
require 'mkit/app/helpers/services_helper'

class ServicesController < MKIt::Server
  helpers MKIt::ServicesHelper

  # curl localhost:4567/services
  get '/services' do
    if params[:verbose]
      verbose = params[:verbose] == 'true'
    else
      verbose = false
    end
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
    if request.env['CONTENT_TYPE'] == 'application/json'
      resp = srv.to_json
    else
      resp = format_response(srv)
    end
    resp
  end

  # curl -X PUT localhost:4567/services/1  -F "file=@mkit/samples/mkit.yml"
  put '/services/:id' do
    srv = find_by_id_or_name
    if params[:file]
      tempfile = params[:file][:tempfile]
      yaml = YAML.load(tempfile.read)
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
    srv = "no file"
    if params[:file]
      tempfile = params[:file][:tempfile]
      yaml = YAML.load(tempfile.read)
      srv = Service.create(yaml.to_o)
    end
    format_response(srv)
  rescue MKIt::BaseException => e
    MKItLogger.debug e
    error e.error_code, e.message
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
end

