require 'mkit/version'

class MkitController < MKIt::Server

  get '/mkit/version' do
    "MKIt version #{MKIt::VERSION}\n"
  end

  put'/mkit/proxy/restart' do
    MKIt::HAProxy.restart
  end

  put'/mkit/proxy/start' do
    MKIt::HAProxy.start
  end

  put'/mkit/proxy/stop' do
    MKIt::HAProxy.stop
  end

  get'/mkit/proxy/status' do
    MKIt::HAProxy.status
  end

end

