require 'shellwords'
require 'mkit/container/registry'
require 'mkit/container/utf8_buffer'

module MKIt
  # Runs a command in a pod through the container runtime and bridges its
  # (TTY) stream to a websocket.
  class ContainerExecCommand
    def initialize(pod, ws, options: {}, containers: Container::Registry.api.containers)
      @containers = containers
      @pod = pod
      @ws = ws
      @detached = options[:detached] == 'true'
      @cmd = Shellwords.split(Array(options[:varargs]).join(' '))
    end

    def register
      @socket = @containers.attach_exec(@pod.name, @cmd, detached: @detached)
      @stdout_thread = Thread.new { pump_output }
      @ws.onmessage { |msg| @socket.write(msg) rescue nil } unless @detached
      @stdout_thread
    end

    def unregister
      @stdout_thread&.kill
      @socket&.close unless @socket&.closed?
    end

    def close
      @ws.close_websocket unless @ws.nil?
    end

    private

    def pump_output
      text = Container::Utf8Buffer.new
      while (data = @socket.readpartial(4096))
        out = text.feed(data)
        @ws.send(out) unless out.empty?
      end
    rescue EOFError, IOError, Errno::ECONNRESET
      # exec finished: send what was held back
      rest = text.flush
      @ws.send(rest) unless rest.empty?
    ensure
      @socket.close unless @socket.closed?
      close
    end
  end
end
