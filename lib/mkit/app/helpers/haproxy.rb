require 'mkit/app/model/setting'
require 'mkit/config/config'

module MKIt
  module HAProxy
    module_function
    
    def start
      %x{#{MKIt::Config.mkit.haproxy.ctrl.start}}
    end
  
    def stop
      %x{#{MKIt::Config.mkit.haproxy.ctrl.stop}}
    end

    def restart
      stop
      start
    end

    def status
      %x{#{MKIt::Config.mkit.haproxy.ctrl.status}}
    end

    def reload
      %x{#{MKIt::Config.mkit.haproxy.ctrl.reload}}
    end

    def create_config_file(filename:, data:)
      File.write("#{MKIt::Config.mkit.haproxy.config_dir}/#{filename}", data)
    end

    def delete_config_file(filename:)
      begin
        File.delete("#{MKIt::Config.mkit.haproxy.config_dir}/#{filename}")
      rescue => e
        puts e
      end
    end
  end
end
