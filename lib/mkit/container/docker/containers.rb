# frozen_string_literal: true

require 'shellwords'
require 'mkit/container/containers'
require 'mkit/container/errors'
require 'mkit/container/docker/payload'
require 'mkit/container/docker/stream_demux'

module MKIt
  module Container
    module Docker
      # Container operations through the Docker Engine API.
      class Containers < Container::Containers
        def initialize(client)
          super()
          @client = client
        end

        # Equivalent of `docker run -d`.
        def run(spec)
          id = create(spec)
          start(id)
          id
        end

        def start(id)
          @client.post("/containers/#{id}/start")
        end

        def stop(id)
          @client.post("/containers/#{id}/stop")
        end

        def remove(id)
          @client.delete("/containers/#{id}", force: true)
        end

        def find(id)
          @client.get("/containers/#{id}/json")
        end

        def exec(id, cmd)
          created = @client.post("/containers/#{id}/exec", exec_config(Shellwords.split(cmd)))
          output = @client.post("/exec/#{created['Id']}/start", 'Detach' => false, 'Tty' => true)
          code = @client.get("/exec/#{created['Id']}/json")['ExitCode']
          raise ExecFailed, "exec '#{cmd[0..30]}' exited with #{code}" unless code.to_i.zero?

          output.to_s
        end

        def logs(id, tail: 20)
          body = @client.get_raw("/containers/#{id}/logs", log_query(tail: tail))
          return '' if body.nil?

          tty?(id) ? body : StreamDemux.decode(body)
        end

        def log_path(id)
          find(id)&.dig('LogPath')
        end

        def tty?(id)
          find(id)&.dig('Config', 'Tty') == true
        end

        def follow_logs(id, **query)
          demux = tty?(id) ? nil : StreamDemux.new
          @client.stream_chunks("/containers/#{id}/logs", log_query(**query)) do |chunk|
            demux ? demux.feed(chunk) { |text| yield text } : yield(chunk)
          end
        end

        def attach_exec(id, cmd, detached: false)
          created = @client.post("/containers/#{id}/exec", exec_config(cmd, detached: detached, stdin: true))
          @client.hijack("/exec/#{created['Id']}/start", 'Detach' => detached, 'Tty' => !detached)
        end

        private

        def create(spec)
          created = post_create(spec)
          if created.nil? # 404: image not present locally, like `docker run` we pull it
            pull_image(spec.image)
            created = post_create(spec)
            raise NotFound, "image #{spec.image} not found" if created.nil?
          end
          created['Id']
        end

        def post_create(spec)
          @client.post('/containers/create', Payload.new(spec).to_h, name: spec.name)
        end

        def pull_image(image)
          from, tag = split_image(image)
          @client.post('/images/create', nil, { fromImage: from, tag: tag }.compact)
        end

        # "repo:5000/img:1.0" => ["repo:5000/img", "1.0"]; digests stay in fromImage
        def split_image(image)
          return [image, nil] if image.include?('@')

          name, _, tag = image.rpartition(':')
          return [image, 'latest'] if name.empty? || tag.include?('/')

          [name, tag]
        end

        def exec_config(cmd, detached: false, stdin: false)
          attach = !detached
          {
            'Cmd' => cmd, 'AttachStdin' => stdin && attach, 'AttachStdout' => attach,
            'AttachStderr' => attach, 'Tty' => attach, 'Detach' => detached
          }
        end

        def log_query(tail: nil, follow: false, timestamps: false, since: nil, until_: nil, details: false)
          { stdout: 1, stderr: 1, tail: tail, follow: follow ? 1 : nil, timestamps: timestamps ? 1 : nil,
            since: since, until: until_, details: details ? 1 : nil }.compact
        end
      end
    end
  end
end
