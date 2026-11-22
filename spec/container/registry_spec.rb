# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/registry'

describe MKIt::Container::Registry do
  after { described_class.configure }

  it 'defaults to the docker runtime' do
    described_class.configure
    api = described_class.api
    assert_instance_of MKIt::Container::Api, api
    assert_instance_of MKIt::Container::Docker::Containers, api.containers
    assert_instance_of MKIt::Container::Docker::Networks, api.networks
    assert_instance_of MKIt::Container::Docker::Volumes, api.volumes
    assert_instance_of MKIt::Container::Docker::Events, api.events
  end

  it 'memoizes the api' do
    assert_same described_class.api, described_class.api
  end

  it 'uses the configured socket, falling back to the default path' do
    described_class.configure(socket: '/tmp/custom.sock')
    assert_equal '/tmp/custom.sock', socket_of(described_class.api)
    described_class.configure(socket: nil)
    assert_equal MKIt::Container::Docker::DEFAULT_SOCKET, socket_of(described_class.api)
  end

  describe '.configure_from' do
    def config(**attrs)
      OpenStruct.new(attrs)
    end

    def container(**attrs)
      OpenStruct.new(attrs)
    end

    it 'uses mkit.container.runtime and socket' do
      described_class.configure_from(config(container: container(runtime: 'docker', socket: '/tmp/c.sock')))
      assert_equal '/tmp/c.sock', socket_of(described_class.api)
    end

    it 'falls back to the legacy mkit.docker.socket' do
      described_class.configure_from(config(docker: container(socket: '/tmp/legacy.sock')))
      assert_equal '/tmp/legacy.sock', socket_of(described_class.api)
    end

    it 'prefers mkit.container.socket over the legacy key' do
      described_class.configure_from(config(container: container(socket: '/tmp/new.sock'),
                                            docker: container(socket: '/tmp/legacy.sock')))
      assert_equal '/tmp/new.sock', socket_of(described_class.api)
    end

    it 'defaults to docker with its default socket without any config' do
      described_class.configure_from(config)
      assert_equal MKIt::Container::Docker::DEFAULT_SOCKET, socket_of(described_class.api)
    end

    it 'rejects an unsupported configured runtime' do
      assert_raises(MKIt::Container::Error) do
        described_class.configure_from(config(container: container(runtime: 'rkt')))
      end
    end
  end

  it 'rejects unknown runtimes' do
    err = assert_raises(MKIt::Container::Error) { described_class.configure(runtime: 'rkt') }
    assert_match(/unsupported container runtime 'rkt'/, err.message)
  end

  def socket_of(api)
    api.containers.instance_variable_get(:@client).socket
  end
end
