# # frozen_string_literal: true
require 'faye/websocket'
require 'eventmachine'
require 'json'
require 'io/console'

module MKIt
  class LogWebSocketClient

    def initialize(uri, options)
      @uri = uri
      @options = options
      trap("SIGINT") do
        puts "Bye..."
        EventMachine.stop
      end
    end

    def doIt
      EM.run {
        ws = Faye::WebSocket::Client.new(@uri, nil, @options)

        ws.on :open do |_event|
          puts "Connected to remote server"
          puts "\r\n"
        end

        ws.on :message do |event|
          puts event.data
        end

        ws.on :error do |event|
          p [:error, event.message]
          ws = nil
          EventMachine.stop
        end

        ws.on :close do |_event|
          ws = nil
          puts "\r\n"
          EventMachine.stop
        end
      }
    end
  end
end
