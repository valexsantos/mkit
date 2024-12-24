require "mkit/cmd/shell_client"

module MKIt
  class DockerExecCommand < MKIt::ShellClient

    def initialize(pod, ws, options: {})
      puts "DockerExecCommand: #{options}"
      @pod = pod
      @ws = ws
      command = "docker exec"
      command += " -it" unless options[:detached] == 'true'
      command += " -d" if options[:detached] == 'true'
      command += " #{@pod.name}"
      command += " #{options[:varargs].join(' ')}" if options[:varargs]
      super(command: command)
    end

    def register
      super do |stdout, stdin, pid|
          @stdout_thread = Thread.new do
            stdout.each_char { |line| @ws.send(line) }
          end

          @stdin_thread = Thread.new do
            @ws.onmessage do |msg|
              stdin.putc msg
            end
          end
          @stdout_thread.join
      end
    end

    def close
      @ws.close_websocket unless @ws.nil?
    end
  end
end

