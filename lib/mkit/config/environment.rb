require 'bundler/setup'
require 'dry-container'
require 'sinatra/activerecord'
require 'rubydns'
require 'sinatra'

require_relative 'initializers/001_hash'
require_relative 'initializers/002_openstruct'

SOCKET_PATH = File.expand_path('/tmp/app.sock')

# sinatra conf
configure do
  # set :public_folder, 'public'
  # set :views, 'app/views'
  set :server, :thin
  # enable/disable the built-in web server
  # set :run, :false
  # server hostname or IP address
  # set :bind, SOCKET_PATH, "localhost:4567"
  # set :port, 4567
  #enable :sessions
  #set :session_secret, 'password_security'
  set :default_content_type, :json
end

