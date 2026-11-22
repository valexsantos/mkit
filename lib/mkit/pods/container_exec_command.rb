require 'shellwords'
require 'mkit/container/registry'

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
      while (data = @socket.readpartial(4096))
        @ws.send(data.force_encoding(Encoding::UTF_8))
      end
    rescue EOFError, IOError, Errno::ECONNRESET
      # exec finished
    ensure
      @socket.close unless @socket.closed?
      close
    end
  end
end
