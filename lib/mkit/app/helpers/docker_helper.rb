# frozen_string_literal: true

require 'mkit/cmd_runner'

module MKIt
  module DockerHelper
    # from ERB template
    def create_instance(cmd)
      MKIt::CmdRunner.run(cmd)
    end

    def start_instance(instance_id)
      MKIt::CmdRunner.run("docker start #{instance_id}")
    end

    def stop_instance(instance_id)
      MKIt::CmdRunner.run("docker stop #{instance_id}")
    end

    def remove_instance(instance)
      MKIt::CmdRunner.run("docker rm -f #{instance}")
    end

    def inspect_instance(instance_id)
      # this one does not work on ubunto MKIt::CmdRunner.run("docker inspect #{instance_id}")
      x = `docker inspect #{instance_id}`
      JSON.parse(x).first
    end

    def execute_local(instance_id, cmd)
      MKIt::CmdRunner.run("docker exec -it #{instance_id} #{cmd}")
    end

    #
    # logs
    #
    def logs(instance_id)
      `docker logs -n 20 #{instance_id}`
    end

    #
    # network
    #

    def create_network(network_name)
      MKIt::CmdRunner.run("docker network create #{network_name}")
    end

    def network_exists?(network_name)
      x = MKIt::CmdRunner.run('docker network ls')
      x.match(/\b#{network_name}\b/)
    end

    def dettach_network(network_id, instance_id)
      MKIt::CmdRunner.run("docker network disconnect #{network_id} #{instance_id}")
    end

    def attach_network(network_id, instance_id)
      MKIt::CmdRunner.run("docker network connect #{network_id} #{instance_id}")
    end

    def remove_network(network_id)
      MKIt::CmdRunner.run("docker network rm #{network_id}")
    end

    #
    # volumes
    #

    def create_volume(volume_name)
      MKIt::CmdRunner.run("docker volume create #{volume_name}")
    end

    def delete_volume(volume_name)
      MKIt::CmdRunner.run("docker volume rm #{volume_name}")
    end

    def inspect_volume(volume_name)
      x = MKIt::CmdRunner.run("docker volume inspect #{volume_name}")
      JSON.parse(x).first
    end
  end
end
