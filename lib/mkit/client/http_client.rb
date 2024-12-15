# frozen_string_literal: true

require 'yaml'
require 'net/http'
require 'json'
require 'net_http_unix'
require 'securerandom'
require 'erb'
require 'uri'
require 'fileutils'

module MKIt
  class HttpClient
    def initialize(server_url, my_id)
      @server_url = server_url
      @my_id = my_id
    end

    #
    # http client
    #

    def client(req)
      req['X-API-KEY'] = @my_id
      uri = URI(@server_url)
      case uri.scheme
      when 'https'
        @client = NetX::HTTPUnix.new(uri.host, uri.port)
        @client.use_ssl = true
        @client.verify_mode = OpenSSL::SSL::VERIFY_NONE
      when 'http'
        @client = NetX::HTTPUnix.new(uri.host, uri.port)
      when 'sock'
        @client = NetX::HTTPUnix.new("unix://#{uri.path}")
      else
        raise InvalidParametersException, 'Invalid mkit server uri. Please check configuration'
      end
      @client.request(req)
    end

    def request(request, request_data = nil)
      req = nil
      uri = request[:uri]
      request[:file] = request_data[:file]

      unless request[:params].nil? || request[:params].empty?
        uri = uri + '?' + request[:params].map { |k, v| "#{k}=#{v}" }.join('&')
      end
      uri = ERB.new(uri).result_with_hash(request_data)
      case request[:verb].to_sym
      when :post
        req = Net::HTTP::Post.new(uri)
        unless request[:file].nil?
          (body, boundary) = attach(request[:file])
          req.body = body
          req['Content-Type'] = "multipart/form-data, boundary=#{boundary}"
        end
      when :put
        req = Net::HTTP::Put.new(uri)
        unless request[:file].nil?
          (body, boundary) = attach(request[:file])
          req.body = body
          req['Content-Type'] = "multipart/form-data, boundary=#{boundary}"
        end
      when :patch
        req = Net::HTTP::Patch.new(uri)
      when :get
        req = Net::HTTP::Get.new(uri)
      when :delete
        req = Net::HTTP::Delete.new(uri)
      when :ws

      end
      client(req).body
    end

    def attach(file)
      boundary = SecureRandom.alphanumeric
      body = []
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=file; filename='#{File.basename(file)}'\r\n"
      body << "Content-Type: text/plain\r\n"
      body << "\r\n"
      body << File.read(file)
      body << "\r\n--#{boundary}--\r\n"
      [body.join, boundary]
    end

  end
end
