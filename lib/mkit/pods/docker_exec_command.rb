require "mkit/cmd/shell_client"

module MKIt
  class DockerExecCommand < MKIt::ShellClient

    def initialize(pod, ws, options: {})
      puts "DockerExecCommand: #{options}"
      @pod = pod
      @ws = ws
      command = "docker exec"
      command += " -it" # if options[:interactive]
      command += " #{@pod.name}"
      command += " #{options[:varargs].join(' ')}" if options[:varargs]
      super(command: command)
    end

    def register
      super do |stdout, stdin, pid|
        begin
          @stdout_thread = Thread.new do
            stdout.each { |line| @ws.send(line.strip!) }
          end

          @stdin_thread = Thread.new do
            @ws.onmessage do |msg|
              stdin.puts msg
            end
          end
          @stdout_thread.join
          @stdin_thread.join
        ensure
          stdout.close
          stdin.close
        end
      end
    end

    def close
      # @stdin_thread.kill unless @stdin_thread.nil?
      # @stdout_thread.kill unless @stdout_thread.nil?
      @ws.close_websocket unless @ws.nil?
    end
  end
end

