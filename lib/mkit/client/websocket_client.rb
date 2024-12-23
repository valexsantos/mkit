# # frozen_string_literal: true
require 'faye/websocket'
require 'eventmachine'
require 'json'
require 'pty'
require 'pry'

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
      trap("SIGINT") do
        puts "Bye..."
        EventMachine.stop
      end
    end

    def request(request, request_data)
      uri = request[:uri]
      unless request[:params].nil? || request[:params].empty?
        uri = uri + '?' + request[:params].map { |k, v| "#{k}=#{v}" }.join('&')
      end
      uri = ERB.new("#{@ws_url}#{uri}").result_with_hash(request_data)

      EM.run {
        ws = Faye::WebSocket::Client.new(uri, nil, @options)

        ws.on :open do |_event|
          # start_shell(ws)
        end

        ws.on :message do |event|
          puts event.data.chomp
        end

        ws.on :error do |event|
          p [:error, event.message]
          ws = nil
          EventMachine.stop
        end

        ws.on :close do |_event|
          ws = nil
          EventMachine.stop
        end

        Thread.new do
          loop do
            input = STDIN.gets.chomp
            if input == 'exit'
              puts "bye..."
              EventMachine.stop
              break
            else
              ws.send(input)
            end
          end
        end
      }
    end
  end
end



