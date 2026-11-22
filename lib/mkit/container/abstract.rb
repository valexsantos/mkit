# frozen_string_literal: true

module MKIt
  module Container
    # Declares the methods a runtime implementation must provide.
    module Abstract
      def abstract_methods(*names)
        names.each do |name|
          define_method(name) do |*_args, **_opts, &_block|
            raise NotImplementedError, "#{self.class} must implement ##{name}"
          end
        end
      end
    end
  end
end
