require 'mkit/exceptions'

module MKIt
  class Server < Sinatra::Base
    set :default_content_type, :json
    # set :dump_errors, false
  end
end
