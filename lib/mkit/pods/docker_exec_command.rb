require 'shellwords'
require 'mkit/docker_client'
require 'mkit/app/helpers/docker_helper'

module MKIt
  # Runs a command in a pod through the Docker socket and bridges its
  # (TTY) stream to a websocket.
  class DockerExecCommand
    include DockerHelper

    def initialize(pod, ws, options: {})
      @pod = pod
      @ws = ws
      @detached = options[:detached] == 'true'
      @cmd = Shellwords.split(Array(options[:varargs]).join(' '))
    end

    def register
      exec = docker.post("/containers/#{@pod.name}/exec", exec_config)
      @socket = docker.hijack("/exec/#{exec['Id']}/start", 'Detach' => @detached, 'Tty' => !@detached)
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

    def exec_config
      {
        'Cmd' => @cmd,
        'AttachStdin' => !@detached,
        'AttachStdout' => !@detached,
        'AttachStderr' => !@detached,
        'Tty' => !@detached,
        'Detach' => @detached
      }
    end

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
