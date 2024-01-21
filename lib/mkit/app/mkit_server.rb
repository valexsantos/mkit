require 'mkit/exceptions'

module MKIt
  class Server < Sinatra::Base
    set :default_content_type, :json
    set :dump_errors, true
    set :show_exceptions, false
    set :raise_errors, false

    error MKIt::BaseException do |e|
      MKItLogger.debug e
      error e.error_code, e.message
    end

    error do |e|
      MKItLogger.debug e
      error 500, "Internal server error: #{e.message}"
    end
  end
end
