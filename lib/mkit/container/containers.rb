# frozen_string_literal: true

require 'mkit/container/abstract'

module MKIt
  module Container
    # Contract for container lifecycle operations.
    class Containers
      extend Abstract

      # run(spec): creates (pulling the image if needed) and starts a container, returns its id
      # find(id): runtime properties as a Hash, nil when the container does not exist
      # exec(id, cmd): runs cmd inside the container and returns its output (raises ExecFailed)
      # logs(id, tail:): last log lines as text
      # log_path(id): log file in the host, nil when the log driver has none
      # follow_logs(id, **query) { |text| }: streams log text as it is produced
      # attach_exec(id, cmd, detached:): starts an interactive exec, returns a bidirectional IO
      abstract_methods :run, :start, :stop, :remove, :find, :exec, :logs, :log_path,
                       :tty?, :follow_logs, :attach_exec
    end
  end
end
