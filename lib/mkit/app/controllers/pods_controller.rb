# frozen_string_literal: true

class PodsController < MKIt::Server
  get '/services/:service_id/pods' do
    "Not implemented\n"
  end

  get '/services/:service_id/pods/:pod_id' do
    "Not implemented\n"
  end

  put '/services/:service_id/pods/:pod_id' do
    "Not implemented\n"
  end

  delete '/services/:service_id/pods/:pod_id' do
    "Not implemented\n"
  end

  post '/services/:service_id/pods' do
    xx = 'no file'
    if params[:file]
      tempfile = params[:file][:tempfile]
      xx = YAML.safe_load(tempfile.read)
      puts xx
    end
    JSON.pretty_generate(JSON.parse(xx.to_json))
  end
end
