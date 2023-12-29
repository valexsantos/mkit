require 'pty'
require 'mkit/exceptions'

module MKIt
  class CmdRunner
    def self.run(cmd)
      result=''
      begin
        PTY.spawn( cmd ) do |stdout, stdin, pid|
          begin
            stdout.each { |line| result << line.strip! }
          rescue Errno::EIO
            # nothing
          end
        end
      rescue PTY::ChildExited
        # nothing
      end
      raise CmdRunnerException.new("command '#{cmd[0..30]}...' returned an error response") if !$?.nil? && $?.exitstatus != 0
      result
    end
  end
end

