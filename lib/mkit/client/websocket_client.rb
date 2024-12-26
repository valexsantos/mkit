# # frozen_string_literal: true
require 'faye/websocket'
require 'eventmachine'
require 'json'
require 'io/console'
require 'mkit/client/console_websocket_client'
require 'mkit/client/log_websocket_client'

module MKIt
  class WebSocketClient

    def initialize(server_url, my_id)
      @server_url = server_url
      @my_id = my_id
      uri = URI(@server_url)
      use_ssl = uri.scheme == 'https'
      @options = use_ssl ? { tls: { :verify_peer => false } } : {}
      @options[:headers] = { 'X-API-KEY' => @my_id }
      url_prefix = use_ssl ? "wss" : "ws"
      @ws_url = "#{url_prefix}://#{uri.host}:#{uri.port}"
    end

    def request(request, request_data)
      uri = request[:uri]
      unless request[:params].nil? || request[:params].empty?
        uri = uri + '?' + request[:params].map { |k| "#{k}=#{request_data[k]}" }.join('&')
      end
      uri = ERB.new("#{@ws_url}#{uri}").result_with_hash(request_data)

      case request[:verb].to_sym
      when :ws_console
        client = ConsoleWebSocketClient.new(uri, @options)
      when :ws
        client = LogWebSocketClient.new(uri, @options)
      end
      client.doIt

    end
  end
end



