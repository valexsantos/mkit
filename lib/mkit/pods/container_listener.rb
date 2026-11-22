require 'mkit/status'
require 'mkit/container/registry'

module MKIt
  class StopThread < RuntimeError; end

  # Consumes the container runtime events and keeps pods and services in sync.
  class ContainerListener
    RECONNECT_DELAY = 2
    # container actions that only require the service status to be recomputed
    STATUS_ACTIONS = %i[kill die stop].freeze

    def initialize(api: Container::Registry.api)
      @api = api
      @queue = Queue.new
    end

    def enqueue(event)
      @queue << event
    end

    def start
      @consumer.run if register_consumer
      register_listener
    end

    def stop
      @listener&.kill
      @consumer&.raise StopThread.new
      MKItLogger.info("container listener stopped")
    end

    private

    def parse_message(event)
      MKItLogger.info("container event received: #{event}")
      case event.kind
      when :container then on_container_event(event)
      when :network then on_network_event(event)
      else MKItLogger.info("\t#{event.kind} #{event.action} <<unknown>>")
      end
    end

    def on_container_event(event)
      pod = Pod.find_by(name: event.container_name)
      return unknown_pod(event, event.container_name) if pod.nil?

      case event.action
      when :create then pod_created(pod, event.container_id)
      when :start then pod_started(pod, event.container_id)
      when *STATUS_ACTIONS then pod.service.update_status!
      else MKItLogger.debug("\t#{event.kind} #{event.action} <<TODO>>")
      end
    end

    def pod_created(pod, container_id)
      pod.pod_id = container_id
      pod.status = MKIt::Status::CREATED
      pod.save
      pod.service.update_status!
    end

    def pod_started(pod, container_id)
      pod.pod_id = container_id
      pod.save
      pod.service.update_status!
    end

    def on_network_event(event)
      info = @api.containers.find(event.container_id)
      return unknown_pod(event, event.container_id) if info.nil?

      pod = Pod.find_by(name: info.name)
      return unknown_pod(event, info.name) if pod.nil?

      case event.action
      when :connect then pod_connected(pod, event)
      else MKItLogger.debug("\t#{event.kind} #{event.action} <<NOOP / TODO>>")
      end
    end

    def pod_connected(pod, event)
      MKItLogger.info("network #{event.action} received for pod #{pod.name}")
      pod.update_ip
      pod.save
    end

    def unknown_pod(event, reference)
      MKItLogger.warn("container event #{event} received, but I don't know anything about pod #{reference}")
    end

    def register_consumer
      return false unless @consumer.nil?

      @consumer = Thread.new do
        running = true
        while running
          begin
            parse_message(@queue.pop)
          rescue StopThread
            running = false
            MKItLogger.info("container consumer ended")
          rescue => e
            MKItLogger.error("error while consuming container event: #{e}", e.message, e.backtrace.join("\n"))
          end
        end
      end
      true
    end

    def register_listener
      @listener = Thread.new { listen }
    end

    # Streams the runtime events; reconnects when the stream drops.
    def listen
      loop do
        begin
          @api.events.each { |event| enqueue event }
          MKItLogger.warn('container event stream closed, reconnecting')
        rescue StandardError => e
          MKItLogger.warn("container event stream error: #{e.message}, reconnecting")
        end
        sleep(RECONNECT_DELAY)
      end
    end
  end
end
