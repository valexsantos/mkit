# frozen_string_literal: true

require 'mkit/app/model/service'
require 'mkit/app/helpers/services_helper'
require 'mkit/app/helpers/params_helper'
require 'mkit/pods/docker_log_listener'
require 'mkit/pods/docker_exec_command'

class ServicesController < MKIt::Server
  helpers MKIt::ServicesHelper
  helpers MKIt::ParamsHelper

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
    if !request.websocket?
      srv.log
    else
      pod = find_srv_pod_by_id_or_name(srv)
      options_parameter = build_options_hash(params: params, options: [:nr_lines, :pods, :follow])
      request.websocket do |ws|
        listener = nil
        ws.onopen do
          settings.sockets << ws
          ws.send("<<<< %s | %s >>>>\n" % [srv.name, srv.pod.first.name])
          listener = MKIt::DockerLogListener.new(pod, ws, options: options_parameter)
          settings.listeners << listener
          listener.register
        end
        ws.onmessage do |msg|
          puts msg
        end
        ws.onclose do
          MKItLogger.info("websocket closed [#{listener}]")
          settings.sockets.delete(ws)
          if listener
            MKItLogger.info("unregister [#{listener}]")
            settings.listeners.delete(listener)
            listener.unregister
          end
        end
      end
    end
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

  get '/services/:id/pods/exec' do
    srv = find_by_id_or_name
    if request.websocket?
      pod = find_srv_pod_by_id_or_name(srv)
      options_parameter = build_options_hash(params: params, options: [:varargs, :interactive, :detached])
      raise MKIt::BaseException.new(400, "Missing parameters") unless options_parameter[:varargs]
      options_parameter[:varargs] = JSON.parse(params['varargs'])
      request.websocket do |ws|
        listener = nil
        ws.onopen do
          settings.sockets << ws
          listener = MKIt::DockerExecCommand.new(pod, ws, options: options_parameter)
          settings.listeners << listener
          listener.register
        end
        ws.onclose do
          MKItLogger.info("websocket closed [#{listener}]")
          settings.sockets.delete(ws)
          if listener
            MKItLogger.info("unregister [#{listener}]")
            settings.listeners.delete(listener)
            listener.unregister
          end
        end
      end
    else
      raise MKIt::BaseException.new(400, "Bad request")
    end
  end
end
