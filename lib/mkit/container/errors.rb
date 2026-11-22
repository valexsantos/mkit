# frozen_string_literal: true

module MKIt
  module Container
    # Base error of the container runtime abstraction.
    class Error < StandardError
      attr_reader :status

      def initialize(message = nil, status: nil)
        super(message)
        @status = status
      end
    end

    # A referenced resource (image, container...) does not exist.
    class NotFound < Error; end

    # A command executed inside a container returned a non zero exit code.
    class ExecFailed < Error; end
  end
end
