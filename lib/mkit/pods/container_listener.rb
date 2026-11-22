require 'mkit/status'
require 'mkit/container/registry'
require 'mkit/pods/pod_reconciler'

module MKIt
  class StopThread < RuntimeError; end

  # Consumes the container runtime events and keeps pods and services in sync.
  class ContainerListener
    RECONNECT_DELAY = 2
    # container actions that only require the service status to be recomputed
    STATUS_ACTIONS = %i[kill stop].freeze
    # lines of the container output reported when it fails
    FAILURE_LOG_LINES = 20
    # exit codes of a process ended by SIGKILL / SIGTERM (e.g. stop, kill, oom)
    SIGNAL_EXIT_CODES = [137, 143].freeze

    def initialize(api: Container::Registry.api, reconciler: PodReconciler.new(containers: api.containers))
      @api = api
      @reconciler = reconciler
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
      when :die then pod_died(pod, event)
      when :destroy then pod_gone(pod)
      when :oom then MKItLogger.error("pod #{pod.name} ran out of memory (see its memory limit in resources)")
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

    # the container runs: its network is up and the ip is known
    def pod_started(pod, container_id)
      pod.pod_id = container_id
      pod.sync_ip(@api.containers.find(container_id))
      pod.save
      pod.service.update_status!
    end

    # the container was removed: the pod no longer has an address nor takes part in the proxy config
    def pod_gone(pod)
      pod.sync_ip(nil)
      pod.save
      pod.service.update_status!
    end

    def pod_died(pod, event)
      report_exit(pod, event)
      pod.service.update_status!
    end

    # Explains why a container ended: exit code, oom, runtime error and its last output.
    def report_exit(pod, event)
      info = @api.containers.find(event.container_id)
      code = event.exit_code || info&.exit_code
      return MKItLogger.info("pod #{pod.name} exited with code 0") if code.to_i.zero? && !info&.oom_killed?

      message = exit_message(pod, code, info)
      SIGNAL_EXIT_CODES.include?(code) && !info&.oom_killed? ? MKItLogger.warn(message) : MKItLogger.error(message)
    end

    def exit_message(pod, code, info)
      lines = ["pod #{pod.name} died with exit code #{code}"]
      lines << 'killed by the runtime: out of memory' if info&.oom_killed?
      lines << "runtime error: #{info.error}" if info&.error
      output = last_output(pod.name)
      lines << "last output:\n#{output}" unless output.empty?
      lines.join("\n\t")
    end

    def last_output(name)
      text = @api.containers.logs(name, tail: FAILURE_LOG_LINES).to_s.strip
      text.lines.map { |line| "\t\t#{line.chomp}" }.join("\n")
    rescue Container::Error => e
      MKItLogger.debug("could not read the output of #{name}: #{e.message}")
      ''
    end

    # only connect events of a container matter; network create/destroy carry no container
    def on_network_event(event)
      return unless event.action == :connect && event.container_id

      info = @api.containers.find(event.container_id)
      return unknown_pod(event, event.container_id) if info.nil?

      pod = Pod.find_by(name: info.name)
      return unknown_pod(event, info.name) if pod.nil?

      pod_connected(pod, event, info)
    end

    # connecting before the container starts yields no ip yet, the start event handles it
    def pod_connected(pod, event, info)
      MKItLogger.info("network #{event.action} received for pod #{pod.name}")
      pod.sync_ip(info)
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

    def reconcile
      @reconciler.call
    rescue StandardError => e
      MKItLogger.warn("could not reconcile the pods: #{e.message}")
    end

    def register_listener
      @listener = Thread.new { listen }
    end

    # Streams the runtime events; reconnects when the stream drops. The events lost while it was
    # down (or before the daemon started) are recovered by reconciling the pods before each subscription.
    def listen
      loop do
        begin
          reconcile
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
