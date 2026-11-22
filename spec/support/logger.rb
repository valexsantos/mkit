# frozen_string_literal: true

require 'logger'

# Silent stand-in for the application logger.
MKItLogger = Logger.new(nil) unless defined?(MKItLogger)
