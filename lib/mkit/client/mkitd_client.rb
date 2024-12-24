# frozen_string_literal: true
require 'mkit/client/http_client'
require 'mkit/client/websocket_client'

module MKIt
  class MKItdClient
    def initialize(request, server_url, my_id)
      case request[:verb].to_sym
      when :ws, :ws_console
        @client = MKIt::WebSocketClient.new(server_url, my_id)
      else
        @client = MKIt::HttpClient.new(server_url, my_id)
      end
    end

    def request(request, request_data)
      # puts "Request: #{request}"
      # puts "Request data: #{request_data}"
      @client.request(request, request_data)
    end 
  end
end

