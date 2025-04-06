require 'pty'
require 'mkit/exceptions'

module MKIt
  class CmdRunner
    def self.run(cmd)
      result=''
      begin
        shell = PTY.spawn( cmd )
        begin
          shell[0].each { |line| result << line.strip! }
        rescue Errno::EIO
          # nothing
        ensure
          shell[0].close
        end
        shell[1].close
        Process.wait(shell[2])
      rescue PTY::ChildExited
        # nothing
      end
      raise CmdRunnerException.new("command '#{cmd[0..30]}...' returned an error [#{result}] (#{$?})") if !$?.nil? && $?.exitstatus != 0
      result
    end
  end
end

