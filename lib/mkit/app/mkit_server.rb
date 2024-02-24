# frozen_string_literal: true

require 'mkit/exceptions'

module MKIt
  class Server < Sinatra::Base
    set :default_content_type, :json
    set :dump_errors, true
    set :show_exceptions, false
    set :raise_errors, false

    before do
      api_key = request.env['HTTP_X_API_KEY']
      cfg = YAML.load_file(MKIt::Config.config_file)
      if cfg.nil? || cfg['mkit'].nil? || cfg['mkit']['clients'].nil? || !cfg['mkit']['clients'].map{|h| h['id']}.include?(api_key)
        error 401, 'Unauthorized - please add your client-id to authorized clients list'
      end
    end

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
