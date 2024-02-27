# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mkit/version'

Gem::Specification.new do |s|
  s.name = 'mkit'
  s.summary      = 'Micro Kubernets on Ruby'
  s.bindir       = 'bin'
  s.homepage     = 'https://github.com/valexsantos/mkit'
  s.license      = 'MIT'
  s.description =  'Micro k8s on Ruby - a simple tool to deploy containers to mimic a (very) minimalistic k8 cluster with a nice REST API'
  # s.require_paths = ["."]
  s.author = 'Vasco Santos'
  s.email        = ['valexsantos@gmail.com']
  s.version      = MKIt::VERSION
  s.platform     = Gem::Platform::RUBY
  s.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|TODO|db/development.sqlite)}) }
  end
  s.executables  << 'mkitd'
  s.executables  << 'mkitc'
  s.add_runtime_dependency 'async-dns', '~> 1.3', '>= 1.3.0'
  s.add_runtime_dependency 'dry-container', '~> 0.9', '>= 0.9.0'
  s.add_runtime_dependency 'net_http_unix',   '~> 0.2', '>= 0.2.2'
  s.add_runtime_dependency 'net-ping', '~> 2.0', '>= 2.0.8'
  s.add_runtime_dependency 'pry',             '~> 0.14', '>= 0.14.2'
  s.add_runtime_dependency 'rack',            '~> 2.2', '>= 2.2.5'
  s.add_runtime_dependency 'rack-protection', '~> 3.0', '>= 3.0.5'
  s.add_runtime_dependency 'rack-test',       '~> 2.0', '>= 2.0.2'
  s.add_runtime_dependency 'rubydns',         '~> 2.0', '>= 2.0.2'
  s.add_runtime_dependency 'sinatra',         '~> 3.0', '>= 3.0.5'
  s.add_runtime_dependency 'sinatra-activerecord', '~> 2.0', '>= 2.0.26'
  s.add_runtime_dependency 'sqlite3', '~> 1.5', '>= 1.5.4'
  s.add_runtime_dependency 'standalone_migrations', '~> 7.1', '>= 7.1.0'
  s.add_runtime_dependency 'thin', '~> 1.8', '>= 1.8.1'
  s.add_runtime_dependency 'text-table', '~> 1.2', '>= 1.2.4'
end
