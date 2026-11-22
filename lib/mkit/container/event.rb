# frozen_string_literal: true

module MKIt
  module Container
    # Runtime neutral event of the container runtime.
    #
    # kind: :container, :network ... (what the event is about)
    # action: :create, :start, :die, :connect ... (without arguments, e.g. exec_start: ls => :exec_start)
    # container_id: container involved (nil when none)
    # container_name: container name when the runtime reports it
    # exit_code: exit code of the process (die events), nil otherwise
    class Event
      attr_reader :kind, :action, :container_id, :container_name, :exit_code

      def initialize(kind:, action:, container_id: nil, container_name: nil, exit_code: nil)
        @kind = kind
        @action = action
        @container_id = container_id
        @container_name = container_name
        @exit_code = exit_code
      end

      def to_s
        text = "<#{kind}> <#{action}> container=#{container_id || '-'} name=#{container_name || '-'}"
        exit_code.nil? ? text : "#{text} exit_code=#{exit_code}"
      end
    end
  end
end
