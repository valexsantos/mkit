# frozen_string_literal: true

require 'mkit/utils'

module MKIt
  module ERBHelper
    def read_template(template)
      root = MKIt::Utils.root
      File.read("#{root}/lib/mkit/app/templates/#{template}.erb")
    end

    def parse_template(template, data = {})
      ERB.new(read_template(template)).result_with_hash(data)
    end

    def parse_model(template)
      ERB.new(read_template(template))
    end
  end
end
