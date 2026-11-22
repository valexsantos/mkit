# frozen_string_literal: true

require 'spec_helper'
require 'support/logger'
require 'mkit/workers/aworker'
require 'mkit/app/helpers/haproxy'

# minimal collaborators, the real ones need the whole application
module MKIt
  module System
    def self.[](_name)
      @job_manager ||= Object.new.tap { |o| o.define_singleton_method(:register_worker) { |*_| } }
    end
  end
end
class Service; end unless defined?(Service)
require 'mkit/workers/haproxy_worker'

describe MKIt::HAProxyWorker do
  let(:worker) { described_class.new }
  let(:service) { stub('service', name: 'web', proxy_filename: '0012_web.cfg') }

  def job(topic, **attrs)
    OpenStruct.new({ topic: topic, service_id: 1 }.merge(attrs))
  end

  before { Service.stubs(:find).with(1).returns(service) }

  %i[update_proxy_config create_proxy_config].each do |topic|
    describe topic.to_s do
      it 'writes the config and reloads when the service has a pod to route to' do
        service.stubs(:routable?).returns(true)
        service.stubs(:proxy_config).returns(filename: '0012_web.cfg', data: 'cfg')
        MKIt::HAProxy.expects(:create_config_file).with(filename: '0012_web.cfg', data: 'cfg')
        MKIt::HAProxy.expects(:delete_config_file).never
        MKIt::HAProxy.expects(:reload)
        worker.do_the(job(topic))
      end

      it 'removes the config and reloads when the service has no pod with an ip' do
        service.stubs(:routable?).returns(false)
        service.expects(:proxy_config).never
        MKIt::HAProxy.expects(:delete_config_file).with(filename: '0012_web.cfg')
        MKIt::HAProxy.expects(:create_config_file).never
        MKIt::HAProxy.expects(:reload)
        worker.do_the(job(topic))
      end
    end
  end

  it 'removes the config of a destroyed service' do
    Service.expects(:find).never
    MKIt::HAProxy.expects(:delete_config_file).with(filename: 'x.cfg')
    MKIt::HAProxy.expects(:reload)
    worker.do_the(job(:destroy_proxy_config, service_id: nil, data: { 'filename' => 'x.cfg' }))
  end

  it 'reloads and restarts on request, without looking for a service' do
    MKIt::HAProxy.expects(:reload)
    MKIt::HAProxy.expects(:restart)
    worker.do_the(job(:reload_proxy, service_id: nil))
    worker.do_the(job(:restart_proxy, service_id: nil))
  end
end
