# frozen_string_literal: true

module MKIt
  module ParamsHelper

    def build_options_hash(params:, options:)
      hash = {}
      puts "Params: #{params}"
      options.each do |option|
        hash[option] = params[option]
      end
      hash
    end

  end
end
