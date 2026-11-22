# frozen_string_literal: true

require 'mkit/container/abstract'

module MKIt
  module Container
    # Contract for container networks.
    class Networks
      extend Abstract

      # find(name): Hash, nil when it does not exist
      abstract_methods :create, :find, :attach, :detach, :remove

      def exists?(name)
        !find(name).nil?
      end
    end
  end
end
