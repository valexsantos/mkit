require 'pty'
#
# 
#
module MKIt
  class HAProxy

    def initialize
      # configs
      # run standalone | daemon
      @running = false
    end

    def start
      @thread ||= Thread.new {
        while (@running) do
        cmd = "/usr/sbin/haproxy -f /etc/haproxy/haproxy.d"
        %x{#{cmd}}
        sleep 1
        end
      }
      @thread.run
      puts "haproxy started"
    end

    def start
      @running = true
      @thread ||= Thread.new {
        while (@running) do
          %{/usr/sbin/haproxy -f /etc/haproxy/haproxy.d/}
          sleep(1)
        end
      }
      puts "proxy started"
    end

    def stop
      puts "proxy stopped"
    end

    def status
    end

    def reload
    end
  end
end

