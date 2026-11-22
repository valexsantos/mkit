require 'mkit/status'
require 'mkit/container/registry'

#
# https://docs.docker.com/engine/api/v1.43/#tag/System/operation/SystemEvents
module MKIt
  class StopThread < RuntimeError; end

  class ContainerListener
    RECONNECT_DELAY = 2

    def initialize(api: Container::Registry.api)
      @api = api
      @queue = Queue.new
    end

    def enqueue(msg)
      @queue << msg
    end

    def start
      @consumer.run if register_consumer
      register_listener
    end

    def stop
      @listener&.kill
      @consumer&.raise StopThread.new
      MKItLogger.info("docker listener stopped")
    end

    private

    def parse_message(msg)
      action = msg['Action'].to_sym
      type = msg['Type'].to_sym
      MKItLogger.info("docker <#{type}> <#{action}> received: \n\t#{msg}")
      case type
      when :container
        pod_id = msg.id
        pod_name = msg.Actor.Attributes.name
        pod = Pod.find_by(name: pod_name)
        unless pod.nil?
          case action
          when :create
            pod.pod_id = pod_id
            pod.status = MKIt::Status::CREATED
            pod.save
            pod.service.update_status!
          when :start
            pod.pod_id = pod_id
            pod.save
            pod.service.update_status!
          when :kill
            pod.service.update_status!
          when :die
            pod.service.update_status!
          when :stop
            pod.service.update_status!
          else
            MKItLogger.debug("	#{type} #{action} <<TODO>>")
          end
        else
          MKItLogger.warn("docker <<#{type}>> <#{action}> received: #{msg}. But I don't know anything about pod #{pod_id}/#{pod_name}")
        end
      when :network
        pod_id = msg.Actor.Attributes.container
        inspect = @api.containers.find(pod_id)
        unless inspect.nil?
          inspect = inspect.to_o
          pod_name = inspect.Name[1..]
          pod = Pod.find_by(name: pod_name)
          unless pod.nil?
            case action
            when :connect
              MKItLogger.info("docker network #{action} received: #{msg} for pod #{pod_name}")
              pod.update_ip
              pod.save
            when :disconnect
              MKItLogger.debug("  #{type} #{action} <<NOOP / TODO>>")
            else
              MKItLogger.debug("  #{type} #{action} <<TODO>>")
            end
          else
            MKItLogger.warn("docker <<#{type}>> <#{action}> received: #{msg}. But I don't know anything about pod #{pod_id}/#{pod_name}")
          end
        else
            MKItLogger.warn("docker <<#{type}>> <#{action}> received: #{msg}. But I don't know anything about pod #{pod_id}")
        end
      else
        MKItLogger.info("\t#{type} #{action} <<unknown>>")
      end
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
            MKItLogger.info("docker consumer ended")
          rescue => e
            MKItLogger.error("error while consuming docker notification: #{e}", e.message, e.backtrace.join("\n"))
          end
        end
      end
      true
    end

    def register_listener
      @listener = Thread.new { listen }
    end

    # Streams /events; reconnects when the stream drops.
    def listen
      loop do
        begin
          @api.events.each { |event| enqueue event.to_o }
          MKItLogger.warn('docker event stream closed, reconnecting')
        rescue StandardError => e
          MKItLogger.warn("docker event stream error: #{e.message}, reconnecting")
        end
        sleep(RECONNECT_DELAY)
      end
    end
  end
end

