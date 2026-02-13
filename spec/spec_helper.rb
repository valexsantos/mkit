# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'json'
require 'yaml'
require 'ostruct'
require 'mocha/minitest'
require_relative '../lib/mkit'

class Minitest::Spec
  def app
    MKIt::Server
  end

  def setup
    ActiveRecord::Base.connection.execute('DELETE FROM services')
    ActiveRecord::Base.connection.execute('DELETE FROM pods')
    ActiveRecord::Base.connection.execute('DELETE FROM vault_secrets')
    ActiveRecord::Base.connection.execute('DELETE FROM persistent_volumes')
    ActiveRecord::Base.connection.execute('DELETE FROM resources')
  end
end
