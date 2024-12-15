# frozen_string_literal: true
module MKIt
  class ExitShell < RuntimeError; end

  class ShellClient
    def initialize(command:)
      @command = command
      @logger = MKItLogger
      @logger.debug("Command initialized: [#{@command}]")
    end

    def unregister
      @logger.info("ending [#{@command}]...")
      if @client
        begin
          @client.raise ExitShell.new
        rescue
          @logger.error("Failed to raise ExitShell")
        end
        @client.exit rescue @logger.warn("Failed to exit client thread")
      end
    end

    def close
      # no op
    end

    def register
      @client = Thread.new {
        begin
          PTY.spawn( @command ) do |stdout, stdin, pid |
            begin
              yield stdout, stdin, pid if block_given?
            rescue Errno::EIO
              @logger.warn(
                "Errno:EIO error, but this probably just means that the process has finished giving output"
              )
            rescue ExitShell
              @logger.info("#{@command} ended")
            ensure
              stdin.close rescue @logger.warn("Failed to close stdin")
              stdout.close rescue @logger.warn("Failed to close stdout")
              begin
                close
              rescue => e
                @logger.warn("Error closing client", e)
              end
              Process.wait(pid)
            end
          end
        rescue PTY::ChildExited
          @logger.info("#{@command} exited.")
        end
      }
    end
  end
end
