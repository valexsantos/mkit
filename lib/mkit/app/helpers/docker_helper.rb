require 'json'
require 'shellwords'
require 'mkit/docker_client'
require 'mkit/docker_container_spec'
require 'mkit/docker_stream_demux'

module MKIt
  # Docker operations through the Engine API (unix socket).
  module DockerHelper
    extend self

    def docker
      MKIt::DockerClient.default
    end

    #
    # containers
    #

    # spec: MKIt::DockerContainerSpec. Equivalent of `docker run -d`.
    def create_instance(spec)
      id = create_container(spec)
      docker.post("/containers/#{id}/start")
      id
    end

    def start_instance(instance_id)
      docker.post("/containers/#{instance_id}/start")
    end

    def stop_instance(instance_id)
      docker.post("/containers/#{instance_id}/stop")
    end

    def remove_instance(instance)
      docker.delete("/containers/#{instance}", force: true)
    end

    def inspect_instance(instance_id)
      docker.get("/containers/#{instance_id}/json")
    end

    # Runs cmd inside the container and returns its output.
    def execute_local(instance_id, cmd)
      exec = docker.post("/containers/#{instance_id}/exec",
                         'Cmd' => Shellwords.split(cmd), 'AttachStdout' => true,
                         'AttachStderr' => true, 'Tty' => true)
      output = docker.post("/exec/#{exec['Id']}/start", 'Detach' => false, 'Tty' => true)
      code = docker.get("/exec/#{exec['Id']}/json")['ExitCode']
      raise MKIt::CmdRunnerException, "exec '#{cmd[0..30]}' exited with #{code}" unless code.to_i.zero?
      output.to_s
    end

    #
    # logs
    #

    def logs(instance_id, tail: 20)
      body = docker.get_raw("/containers/#{instance_id}/logs", log_query(tail: tail))
      return '' if body.nil?

      tty?(instance_id) ? body : MKIt::DockerStreamDemux.decode(body)
    end

    def logfile(instance_id)
      inspect_instance(instance_id)&.dig('LogPath')
    end

    def clear_logs(instance_id)
      path = logfile(instance_id)
      File.write(path, '') unless path.nil? || path.empty?
    end

    def tty?(instance_id)
      inspect_instance(instance_id)&.dig('Config', 'Tty') == true
    end

    def log_query(tail: nil, follow: false, timestamps: false, since: nil, until_: nil, details: false)
      { stdout: 1, stderr: 1, tail: tail, follow: follow ? 1 : nil, timestamps: timestamps ? 1 : nil,
        since: since, until: until_, details: details ? 1 : nil }.compact
    end

    #
    # network
    #

    def create_network(network_name)
      docker.post('/networks/create', 'Name' => network_name)
    end

    def inspect_network(network_name)
      docker.get("/networks/#{network_name}")
    end

    def network_exists?(network_name)
      !inspect_network(network_name).nil?
    end

    def dettach_network(network_id, instance_id)
      docker.post("/networks/#{network_id}/disconnect", 'Container' => instance_id)
    end

    def attach_network(network_id, instance_id)
      docker.post("/networks/#{network_id}/connect", 'Container' => instance_id)
    end

    def remove_network(network_id)
      docker.delete("/networks/#{network_id}")
    end

    #
    # volumes
    #

    def create_volume(volume_name)
      docker.post('/volumes/create', 'Name' => volume_name)
    end

    def delete_volume(volume_name)
      docker.delete("/volumes/#{volume_name}")
    end

    def inspect_volume(volume_name)
      docker.get("/volumes/#{volume_name}")
    end

    ##
    # cpu limits
    def to_docker_cpu_limit(k8s_cpu_limits)
      return nil if k8s_cpu_limits.nil?

      cpu_limit = k8s_cpu_limits.to_s
      cpu_limit = (cpu_limit.delete_suffix('m').to_f / 1000).to_s if cpu_limit.include?('m')
      cpu_limit
    end

    private

    def create_container(spec)
      created = post_create(spec)
      if created.nil? # 404: image not present locally, like `docker run` we pull it
        pull_image(spec.image)
        created = post_create(spec)
        raise MKIt::DockerApiException, "image #{spec.image} not found" if created.nil?
      end
      created['Id']
    end

    def post_create(spec)
      docker.post('/containers/create', spec.to_h, name: spec.name)
    end

    def pull_image(image)
      from, tag = split_image(image)
      docker.post('/images/create', nil, { fromImage: from, tag: tag }.compact)
    end

    # "repo:5000/img:1.0" => ["repo:5000/img", "1.0"]; digests stay in fromImage
    def split_image(image)
      return [image, nil] if image.include?('@')
      name, _, tag = image.rpartition(':')
      return [image, 'latest'] if name.empty? || tag.include?('/')
      [name, tag]
    end
  end
end
