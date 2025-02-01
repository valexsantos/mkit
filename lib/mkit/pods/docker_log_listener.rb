require "mkit/cmd/shell_client"
require "mkit/app/helpers/docker_helper"

module MKIt
  class DockerLogListener < MKIt::ShellClient

    include DockerHelper

    def initialize(pod, ws, options: {})
      if options[:clear]
        clear_logs(pod.name)
      end
      @pod = pod
      @ws = ws
      command = "docker logs"
      command += " -f" if options[:follow] == 'true'
      command += " -n #{options[:nr_lines]}" if options[:nr_lines]
      command += " -n 10" unless options[:nr_lines]
      command += " -t" if options[:timestamps] == 'true'
      command += " --since #{options[:since]}" if options[:since]
      command += " --until #{options[:until]}" if options[:until]
      command += " --details" if options[:details] == 'true'
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

