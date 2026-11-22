require 'mkit/container/registry'

module MKIt
  # Streams a pod's logs to a websocket through the container runtime.
  class ContainerLogListener
    DEFAULT_LINES = 10

    def initialize(pod, ws, options: {}, containers: Container::Registry.api.containers)
      @containers = containers
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
      {
        tail: @options[:nr_lines] || DEFAULT_LINES,
        follow: @options[:follow] == 'true',
        timestamps: @options[:timestamps] == 'true',
        details: @options[:details] == 'true',
        since: @options[:since],
        until_: @options[:until]
      }
    end

    def clear_logs(name)
      path = @containers.log_path(name)
      File.write(path, '') unless path.nil? || path.empty?
    end

    def stream_logs
      pending = +''
      @containers.follow_logs(@pod.name, **query) { |text| pending = send_lines(pending + text) }
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
