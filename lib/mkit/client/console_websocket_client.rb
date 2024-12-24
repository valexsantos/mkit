# # frozen_string_literal: true
require 'faye/websocket'
require 'eventmachine'
require 'json'
require 'io/console'

module MKIt
  class ConsoleWebSocketClient

    def initialize(uri, options)
      @uri = uri
      @options = options
    end

    def doIt
      EM.run {
        ws = Faye::WebSocket::Client.new(@uri, nil, @options)

        ws.on :open do |_event|
          puts "Connected to WebSocket server"
          puts "\r\n"
        end

        ws.on :message do |event|
          print event.data
        end

        ws.on :error do |event|
          p [:error, event.message]
          ws = nil
          puts "\r\n"
          EventMachine.stop
        end

        ws.on :close do |_event|
          ws = nil
          EventMachine.stop
        end

        Thread.new do
          STDIN.raw do
            loop do
              input = STDIN.getc.chr
              # if input == "\u0003" # Ctrl+C
              #   puts "bye..."
              #   EventMachine.stop
              #   break
              # else
                ws.send(input)
              # end
            end
          end
        end
      }
    end
  end
end
