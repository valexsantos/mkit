require 'mkit/docker_client'
require 'mkit/docker_stream_demux'
require 'mkit/app/helpers/docker_helper'

module MKIt
  # Streams a pod's logs to a websocket through the Docker socket.
  class DockerLogListener
    include DockerHelper

    DEFAULT_LINES = 10

    def initialize(pod, ws, options: {})
      clear_logs(pod.name) if options[:clear]
      @pod = pod
      @ws = ws
      @options = options
    end

    def register
      @client = Thread.new do
        begin
          stream_logs
        rescue StandardError => e
          MKItLogger.warn("log stream for #{@pod.name} ended: #{e.message}")
        ensure
          close
        end
      end
    end

    def unregister
      @client&.kill
    end

    def close
      @ws.close_websocket unless @ws.nil?
    end

    private

    def query
      log_query(
        tail: @options[:nr_lines] || DEFAULT_LINES,
        follow: @options[:follow] == 'true',
        timestamps: @options[:timestamps] == 'true',
        details: @options[:details] == 'true',
        since: @options[:since],
        until_: @options[:until]
      )
    end

    def stream_logs
      demux = tty?(@pod.name) ? nil : MKIt::DockerStreamDemux.new
      pending = +''
      docker.stream_chunks("/containers/#{@pod.name}/logs", query) do |chunk|
        emit = ->(text) { pending = send_lines(pending + text) }
        demux ? demux.feed(chunk, &emit) : emit.call(chunk)
      end
      @ws.send(pending) unless pending.empty?
    end

    # sends complete lines, returns the unfinished remainder
    def send_lines(text)
      lines = text.split("\n", -1)
      rest = lines.pop
      lines.each { |line| @ws.send(line) }
      rest
    end
  end
end
