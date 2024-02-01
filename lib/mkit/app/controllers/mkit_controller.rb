require 'mkit/version'

class MkitController < MKIt::Server

  get '/mkit/version' do
    "MKIt version #{MKIt::VERSION}\n"
  end

  put'/mkit/proxy/restart' do
    MKIt::HAProxy.restart
  end

  get'/mkit/proxy/status' do
    MKIt::HAProxy.status
  end

end

