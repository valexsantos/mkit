ENV["SINATRA_ENV"] ||= "development"

require 'rubygems'
require 'sinatra/activerecord/rake'
require 'standalone_migrations'
require 'rubygems/package_task'
require 'rubygems/specification'
require 'rake/testtask'
require 'pry'
require 'fileutils'
require 'bundler/setup'
require 'dry-container'
require 'sinatra/activerecord'
require 'rubydns'
require_relative 'lib/mkit/version.rb'
require_relative 'lib/mkit/utils'
require_relative 'lib/mkit'

$LOAD_PATH.unshift File.expand_path('lib')
rails_env=ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
# db migrations, use database config
ENV["DATABASE_URL"]=MKIt::Utils.db_config_to_uri(rails_env)

desc 'Builds the gem'
task :package do
  sh %{gem build "mkit.gemspec"}
end

task :install => [:package] do
  sh %{gem install mkit-#{MKIt::VERSION}.gem}
end

desc 'Copy rb to packaging dir'
task :build => [:init] do
  FileUtils.cp_r('app', 'target/build', {:remove_destination=>true})
  FileUtils.cp_r('config', 'target/build', {:remove_destination=>true})
  FileUtils.cp_r('bin', 'target/build', {:remove_destination=>true})
  FileUtils.cp_r('lib', 'target/build', {:remove_destination=>true})
  FileUtils.cp_r('config.ru', 'target/build', {:remove_destination=>true})
end

desc 'Create build dirs'
task :init do
  FileUtils.mkdir_p('target/build')
  FileUtils.mkdir_p('target/package')
end

desc "Rake Console"
task :console do
  Pry.start
end

StandaloneMigrations::Tasks.load_tasks

