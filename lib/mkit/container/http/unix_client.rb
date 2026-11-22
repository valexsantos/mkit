# frozen_string_literal: true

require 'json'
require 'socket'
require 'uri'
require 'net_x/http_unix'
require 'mkit/container/errors'

module MKIt
  module Container
    module Http
      # Minimal JSON/HTTP client over a unix socket, as spoken by container runtimes.
      class UnixClient
        DEFAULT_READ_TIMEOUT = 60

        attr_reader :socket

        def initialize(socket:)
          @socket = socket
        end

        # Returns parsed JSON (or raw body when not JSON); nil when not found (404).
        def get(path, query = {})
          request(:get, path, query: query)
        end

        def post(path, body = nil, query = {})
          request(:post, path, body: body, query: query)
        end

        def delete(path, query = {})
          request(:delete, path, query: query)
        end

        # Raw (non-JSON) response body, nil when not found.
        def get_raw(path, query = {})
          raw_request(:get, path, query: query)
        end

        # POST whose response is not JSON (exec output, image pull progress), nil when not found.
        # Long operations (pulls) need a bigger read_timeout.
        def post_raw(path, body = nil, query = {}, read_timeout: DEFAULT_READ_TIMEOUT)
          raw_request(:post, path, body: body, query: query, read_timeout: read_timeout)
        end

        # Yields raw chunks as they arrive. Blocks until the connection closes.
        def stream_chunks(path, query = {}, &block)
          http = connection(read_timeout: nil)
          http.request(build(:get, path, query: query)) do |res|
            raise_for(res) unless res.is_a?(Net::HTTPSuccess)
            res.read_body(&block)
          end
        end

        # Streams newline-delimited JSON objects (e.g. /events) to the block.
        def stream(path, query = {})
          buffer = +''
          stream_chunks(path, query) do |chunk|
            buffer << chunk
            while (line = buffer.slice!(/\A.*\n/))
              line = line.strip
              yield JSON.parse(line) unless line.empty?
            end
          end
        end

        # POST that upgrades the connection to a raw bidirectional stream
        # (exec start). Returns the connected socket; the caller must close it.
        def hijack(path, body)
          payload = body.to_json
          sock = UNIXSocket.new(@socket)
          sock.write("POST #{path} HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\n" \
                     "Connection: Upgrade\r\nUpgrade: tcp\r\nContent-Length: #{payload.bytesize}\r\n\r\n#{payload}")
          status = sock.gets.to_s
          while (line = sock.gets) && line != "\r\n"; end
          unless status =~ %r{\AHTTP/1\.\d (101|200)}
            sock.close
            raise Error.new("hijack failed: #{status.strip}", status: status.split[1].to_i)
          end
          sock
        rescue Errno::ENOENT, Errno::ECONNREFUSED, Errno::EACCES => e
          raise Error, "cannot reach socket #{@socket}: #{e.message}"
        end

        private

        def connection(read_timeout: DEFAULT_READ_TIMEOUT)
          http = NetX::HTTPUnix.new("unix://#{@socket}")
          http.read_timeout = read_timeout
          http
        end

        def build(method, path, body: nil, query: {})
          uri = query.empty? ? path : "#{path}?#{URI.encode_www_form(query)}"
          req = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
          unless body.nil?
            req['Content-Type'] = 'application/json'
            req.body = body.to_json
          end
          req
        end

        def request(method, path, body: nil, query: {})
          parse(raw_request(method, path, body: body, query: query))
        end

        def raw_request(method, path, body: nil, query: {}, read_timeout: DEFAULT_READ_TIMEOUT)
          res = connection(read_timeout: read_timeout).request(build(method, path, body: body, query: query))
          return nil if res.is_a?(Net::HTTPNotFound)

          raise_for(res) unless ok?(res)
          res.body
        rescue Errno::ENOENT, Errno::ECONNREFUSED, Errno::EACCES => e
          raise Error, "cannot reach socket #{@socket}: #{e.message}"
        rescue Net::ReadTimeout, Net::OpenTimeout => e
          raise Error, "timeout talking to #{@socket} (#{method.to_s.upcase} #{path}): #{e.message}"
        end

        # 304: already started/stopped
        def ok?(res)
          res.is_a?(Net::HTTPSuccess) || res.is_a?(Net::HTTPNotModified)
        end

        def parse(body)
          return nil if body.nil? || body.empty?

          JSON.parse(body)
        rescue JSON::ParserError
          body
        end

        def raise_for(res)
          msg = (JSON.parse(res.body)['message'] rescue res.body)
          raise Error.new(msg, status: res.code.to_i)
        end
      end
    end
  end
end
