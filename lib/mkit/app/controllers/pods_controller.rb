# frozen_string_literal: true

require 'mkit/app/model/pod'
require 'mkit/app/helpers/pods_helper'
require 'mkit/app/helpers/params_helper'
require 'mkit/pods/docker_exec_command'
require 'mkit/exceptions'

class PodsController < MKIt::Server
  helpers MKIt::PodsHelper
  helpers MKIt::ParamsHelper

  get '/services/:service_id/pods' do
    "Not implemented\n"
  end

  get '/services/:service_id/pods/:pod_id' do
    "Not implemented\n"
  end

  get '/pods/:id/exec' do
    pod = find_by_id_or_name
    if request.websocket?
      options_parameter = build_options_hash(params: params, options: [:varargs])
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

  delete '/services/:service_id/pods/:pod_id' do
    "Not implemented\n"
  end

  post '/services/:service_id/pods' do
    "Not implemented\n"
  end
end
