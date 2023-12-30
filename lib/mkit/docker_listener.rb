require 'pty'
require 'mkit/status'

#
# https://docs.docker.com/engine/reference/commandline/events
require 'mkit/app/helpers/docker_helper'
module MKIt
  class DockerListener
    include MKIt::DockerHelper

    def initialize
      @consumers = []
    end

    def register_consumer(consumer:)
    end

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
            MKItLogger.debug("	#{type} #{action} <<NOOP / TODO>>")
          when :die
            MKItLogger.debug("	#{type} #{action} <<NOOP / TODO>>")
          when :stop
            pod.service.update_status!
          else
            MKItLogger.debug("	#{type} #{action} <<TODO>>")
          end
        else
          MKItLogger.warn("docker <<#{type}>> <#{action}> received: #{msg}. But I don't know anything about pod #{pod_id}")
        end
      when :network
        pod_id = msg.Actor.Attributes.container
        pod = Pod.find_by(pod_id: pod_id)
        unless pod.nil?
          case action
          when :connect
            MKItLogger.info("docker network #{action} received: #{msg}")
            pod.update_ip
            pod.save
          when :disconnect
            MKItLogger.debug("  #{type} #{action} <<NOOP / TODO>>")
          else
            MKItLogger.debug("  #{type} #{action} <<TODO>>")
          end
        else
          MKItLogger.warn("docker <<#{type}>> <#{action}> received: #{msg}. But I don't know anything about pod #{pod_id}")
        end
      else
        MKItLogger.info("\t#{type} #{action} <<unknown>>")
      end
    end

    def start
      @thread ||= Thread.new {
        cmd = "docker events --format '{{json .}}'"
        begin
          PTY.spawn( cmd ) do |stdout, stdin, pid|
            begin
              stdout.each { |line| parse_message JSON.parse(line).to_o }
            rescue Errno::EIO
              MKItLogger.warn("Errno:EIO error, but this probably just means " +
                "that the process has finished giving output")
            end
          end
        rescue PTY::ChildExited
          MKItLogger.warn("docker event listener process exited!")
        end
      }
      @thread.run
      MKItLogger.info("docker listener started")
    end
    def stop
      @thread.exit if @thread
      MKItLogger.info("docker listener stopped")
    end
  end
end

