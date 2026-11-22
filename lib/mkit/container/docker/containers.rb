# frozen_string_literal: true

require 'json'
require 'shellwords'
require 'mkit/container/containers'
require 'mkit/container/errors'
require 'mkit/container/docker/payload'
require 'mkit/container/docker/mapper'
require 'mkit/container/docker/stream_demux'
require 'mkit/container/utf8_buffer'

module MKIt
  module Container
    module Docker
      # Container operations through the Docker Engine API.
      class Containers < Container::Containers
        PULL_TIMEOUT = 600

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
          inspect = inspect_raw(id)
          inspect.nil? ? nil : Mapper.info(inspect)
        end

        def exec(id, cmd)
          exec_id = create_exec(id, exec_config(Shellwords.split(cmd)))
          output = @client.post_raw("/exec/#{exec_id}/start", { 'Detach' => false, 'Tty' => true })
          code = @client.get("/exec/#{exec_id}/json")['ExitCode']
          raise ExecFailed, "exec '#{cmd[0..30]}' exited with #{code}" unless code.to_i.zero?

          output.to_s
        end

        def logs(id, tail: 20)
          body = @client.get_raw("/containers/#{id}/logs", log_query(tail: tail))
          return '' if body.nil?

          tty?(id) ? Container::Utf8Buffer.decode(body) : StreamDemux.decode(body)
        end

        def log_path(id)
          inspect_raw(id)&.dig('LogPath')
        end

        def follow_logs(id, **query)
          decoder = tty?(id) ? Container::Utf8Buffer.new : StreamDemux.new
          @client.stream_chunks("/containers/#{id}/logs", log_query(**query)) do |chunk|
            feed_logs(decoder, chunk) { |text| yield text }
          end
          flush_logs(decoder) { |text| yield text }
        end

        def attach_exec(id, cmd, detached: false)
          exec_id = create_exec(id, exec_config(cmd, detached: detached, stdin: true))
          @client.hijack("/exec/#{exec_id}/start", 'Detach' => detached, 'Tty' => !detached)
        end

        private

        # tty streams are raw bytes, the others are multiplexed frames
        def feed_logs(decoder, chunk)
          if decoder.is_a?(StreamDemux)
            decoder.feed(chunk) { |text| yield text }
          else
            text = decoder.feed(chunk)
            yield text unless text.empty?
          end
        end

        def flush_logs(decoder)
          if decoder.is_a?(StreamDemux)
            decoder.flush { |text| yield text }
          else
            text = decoder.flush
            yield text unless text.empty?
          end
        end

        def inspect_raw(id)
          @client.get("/containers/#{id}/json")
        end

        def tty?(id)
          inspect_raw(id)&.dig('Config', 'Tty') == true
        end

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

        # the daemon answers 404 when the container does not exist
        def create_exec(id, config)
          created = @client.post("/containers/#{id}/exec", config)
          raise NotFound, "container #{id} not found" if created.nil?

          created['Id']
        end

        # Pulls can take minutes and report failures (auth, rate limit) inside the progress stream.
        def pull_image(image)
          from, tag = split_image(image)
          progress = @client.post_raw('/images/create', nil, { fromImage: from, tag: tag }.compact,
                                      read_timeout: PULL_TIMEOUT)
          raise_pull_error(image, progress)
        end

        def raise_pull_error(image, progress)
          progress.to_s.each_line do |line|
            message = pull_error(line)
            raise Error, "could not pull #{image}: #{message}" if message
          end
        end

        def pull_error(line)
          JSON.parse(line)['error']
        rescue JSON::ParserError
          nil
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
