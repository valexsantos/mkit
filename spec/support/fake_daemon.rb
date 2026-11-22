# frozen_string_literal: true

require 'socket'

# Tiny fake container daemon on a unix socket.
# routes[[verb, path]] = [status, body]; unknown routes answer 404.
module FakeDaemon
  def with_daemon(routes)
    dir = Dir.mktmpdir
    path = File.join(dir, 'runtime.sock')
    server = UNIXServer.new(path)
    requests = []
    t = Thread.new { serve(server, routes, requests) }
    yield path, requests
  ensure
    t&.kill
    FileUtils.rm_rf(dir) if dir
  end

  private

  def serve(server, routes, requests)
    loop do
      c = server.accept
      line = c.gets or next c.close
      verb, target, = line.split
      len = 0
      while (h = c.gets) && h != "\r\n"
        len = h.split(':').last.to_i if h =~ /content-length/i
      end
      body = len.positive? ? c.read(len) : nil
      requests << [verb, target, body]
      status, resp = routes[[verb, target.split('?').first]] || [404, '{"message":"nope"}']
      c.write "HTTP/1.1 #{status} X\r\nContent-Length: #{resp.bytesize}\r\nConnection: close\r\n\r\n#{resp}"
      c.close
    end
  end
end

Minitest::Spec.include FakeDaemon
