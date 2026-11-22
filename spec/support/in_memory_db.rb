# frozen_string_literal: true

require 'active_record'
require 'mkit/config/initializers/003_custom_exceptions'

# Model specs run against a throwaway in-memory sqlite database; each spec creates the
# tables it needs (db/schema.rb is not kept up to date with the migrations).
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Migration.verbose = false
