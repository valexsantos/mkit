# frozen_string_literal: true

require 'mkit/container/abstract'

module MKIt
  module Container
    # Contract for the runtime event stream.
    class Events
      extend Abstract

      # each { |event| }: blocks yielding Container::Event until the stream closes
      abstract_methods :each
    end
  end
end
