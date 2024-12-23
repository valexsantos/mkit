require "mkit/cmd/shell_client"

module MKIt
  class DockerLogListener < MKIt::ShellClient

    def initialize(pod, ws, options: {})
      @pod = pod
      @ws = ws
      command = "docker logs"
      command += " -f" if options[:follow] == 'true'
      command += " -n #{options[:nr_lines]}" if options[:nr_lines]
      command += " -n 10" unless options[:nr_lines]
      command += " #{@pod.name}"
      super(command: command)
    end

    def register
      super do |stdout, stdin, pid|
        stdout.each {
          |line| @ws.send(line.strip!)
        }
      end
    end

    def close
      @ws.close_websocket unless @ws.nil?
    end
  end
end

