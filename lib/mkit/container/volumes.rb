# frozen_string_literal: true

require 'mkit/container/abstract'

module MKIt
  module Container
    # Contract for named volumes.
    class Volumes
      extend Abstract

      # find(name): Hash, nil when it does not exist
      abstract_methods :create, :find, :remove
    end
  end
end
