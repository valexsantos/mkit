# encoding: UTF-8

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "mkit/version"

Gem::Specification.new do |s|
        s.name         = 'mkit'
        s.summary      = 'micro kubernets'
        s.bindir       = 'bin'
        s.homepage     = 'http://vars.pt'
        s.license      = 'Apache-2.0'
        s.rubyforge_project = ''
        s.description  = 'micro kubernets impl'
        # s.require_paths = ["."]
        s.author      = 'Vasco Santos'
        s.email        = ['valexsantos@gmail.com']
        s.version      = MKIt::VERSION
        s.platform     = Gem::Platform::RUBY
        s.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
          `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|TODO|db/development.sqlite)}) }
        end
        s.executables  << 'mkitd'
        s.executables  << 'mkitc'
        s.add_runtime_dependency 'net-ping', '~> 2.0', '>= 2.0.8'
        s.add_runtime_dependency 'dry-container', '~> 0.9', '>= 0.9.0'
        s.add_runtime_dependency 'sqlite3', '~> 1.5', '>= 1.5.4'
        s.add_runtime_dependency 'standalone_migrations', '~> 7.1', '>= 7.1.0'
        s.add_runtime_dependency 'sinatra-activerecord', '~> 2.0', '>= 2.0.26'
        s.add_runtime_dependency 'rack',            '~> 2.2', '>= 2.2.5'
        s.add_runtime_dependency 'rack-protection', '~> 3.0',  '>= 3.0.5'
        s.add_runtime_dependency 'rack-test',       '~> 2.0',  '>= 2.0.2'
        s.add_runtime_dependency 'pry',             '~> 0.14', '>= 0.14.2'
        s.add_runtime_dependency 'rubydns',         '~> 2.0',  '>= 2.0.2'
        s.add_runtime_dependency 'async-dns',       '~> 1.3',  '>= 1.3.0'
        s.add_runtime_dependency 'sinatra',         '~> 3.0',  '>= 3.0.5'
        s.add_runtime_dependency 'thin',            '~> 1.8',  '>= 1.8.1'
        s.add_runtime_dependency 'net_http_unix',   '~> 0.2',  '>= 0.2.2'
end

