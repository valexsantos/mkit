# frozen_string_literal: true

ENV['RACK_ENV'] ||= 'test'
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'mocha/minitest'
require 'ostruct'
require 'fileutils'
require 'tmpdir'
Dir[File.join(__dir__, 'support', '*.rb')].sort.each { |f| require f }

# rspec style helper: the class passed to the closest `describe`
class Minitest::Spec
  def described_class
    klass = self.class
    klass = klass.superclass until klass.desc.is_a?(Module)
    klass.desc
  end
end
