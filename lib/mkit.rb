# frozen_string_literal: true

require 'rubygems'
require 'bundler'
require 'json'
require 'yaml'
require 'optparse'
require 'ostruct'
require 'timeout'
require 'net/http'
require 'sinatra/base'
require 'mkit/config/environment'
require 'mkit/app/mkit_server'
require 'mkit/config/load_default_configs'
require_relative 'mkit/version'
require_relative 'mkit/mkit_interface'
require_relative 'mkit/mkit_dns'
require_relative 'mkit/docker_listener'
require 'mkit/app/helpers/haproxy'
require 'mkit/app/controllers/services_controller'
require 'mkit/app/controllers/mkitjobs_controller'
require 'mkit/app/controllers/mkit_controller'
require 'mkit/mkit_interface'
require 'mkit/mkit_dns'
require 'mkit/job_manager'
require 'mkit/workers/worker_manager'
require 'mkit/sagas/saga_manager'
require 'mkit/docker_listener'
require 'mkit/app/helpers/haproxy'
require 'active_record/tasks/database_tasks'
require 'mkit/utils'
require 'mkit/ssl/easy_ssl'

MKItLogger = Console.logger

module MKIt
  class Error < StandardError; end
  include ActiveRecord::Tasks

  System = Dry::Container.new

  def self.configure(options:)
    @root = MKIt::Utils.root
    @options = options
    MKItLogger.debug!
    #
    # config dir
    @config_dir = if ENV['RACK_ENV'] != 'development'
                    @options[:config_dir].nil? ? '/etc/mkit' : @options[:config_dir]
                  else
                    @options[:config_dir].nil? ? "#{@root}/config" : @options[:config_dir]
                  end
    MKIt::Utils.set_config_dir(@config_dir)
    # defaults
    @bind = options[:bind] ||= 'localhost'
    @port = options[:port] ||= 4567
    @ssl = options[:ssl]  ||= true
    @verify_peer = options[:verify_peer] ||= false
    @cert_chain_file = options[:cert_chain_file] ||= "#{@config_dir}/#{MKIt::Utils::MKIT_CRT}"
    @private_key_file = options[:private_key_file] ||= "#{@config_dir}/#{MKIt::Utils::MKIT_KEY}"

    # create dirs
    if ENV['RACK_ENV'] != 'development' || !options[:config_dir].nil?
      check_config_files = false
      unless File.exist?(@config_dir)
        FileUtils.mkdir_p(@config_dir)
        check_config_files = true
      end
      FileUtils.mkdir_p('/var/lib/mkitd') unless File.exist?('/var/lib/mkitd')
      FileUtils.cp("#{@root}/config/mkit_config.yml", @config_dir) unless File.exist?("#{@config_dir}/mkit_config.yml")
      FileUtils.cp("#{@root}/config/database.yml", @config_dir) unless File.exist?("#{@config_dir}/database.yml")
      FileUtils.cp("#{@root}/config/mkitd_config.sh", @config_dir) unless File.exist?("#{@config_dir}/mkitd_config.sh")
      if check_config_files
        MKItLogger.info "Configuration files copied to #{@config_dir}. Please check it and restart."
        exit
      end
    end

    # load configuration
    MKIt::Initializers.load_my_configuration
    # cert
    MKIt::EasySSL.create_self_certificate(@config_dir)
    #
    # run config based tasks
    FileUtils.mkdir_p(MKIt::Config.mkit.haproxy.config_dir)
    # ...haproxy defaults file
    unless File.exist?("#{MKIt::Config.mkit.haproxy.config_dir}/0000_defaults.cfg")
      FileUtils.cp(
        "#{MKIt::Utils.root}/lib/mkit/app/templates/haproxy/0000_defaults.cfg",
        MKIt::Config.mkit.haproxy.config_dir
      )
    end
    #
    #  conn = { adapter: "sqlite3", database: ":memory:" }
    #  ActiveRecord::Base.establish_connection(conn)
    #  include ActiveRecord::Tasks
    #  DatabaseTasks.database_configuration = YAML.load_file('my_database_config.yml')
    #  DatabaseTasks.db_dir = 'db'
    #
    DatabaseTasks.database_configuration = MKIt::Utils.load_db_config
    DatabaseTasks.env = MKIt::Config.mkit.database.env
    DatabaseTasks.migrations_paths = ["#{@root}/db/migrate"]
    DatabaseTasks.db_dir = 'db'
    DatabaseTasks.root = @root
  end

  def self.options(server)
    if @ssl
      ssl_options = {
        private_key_file:  @private_key_file,
        cert_chain_file: @cert_chain_file,
        verify_peer: @verify_peer
      }
      server.ssl = true
      server.ssl_options = ssl_options
    end
    server.backend.port = @port
    server.backend.host = @bind
  end

  def self.establish_db_connection
    ActiveRecord::Base.establish_connection(DatabaseTasks.database_configuration[DatabaseTasks.env])
    ActiveRecord::Base.connection.migration_context.migrations_paths.clear
    ActiveRecord::Base.connection.migration_context.migrations_paths << "#{@root}/db/migrate"
    MKItLogger.debug "database_tasks migration paths     #{DatabaseTasks.migrations_paths}"
    MKItLogger.debug "active_record_base migration_paths #{ActiveRecord::Base.connection.migration_context.migrations_paths.inspect}"
    MKItLogger.debug "active_record_base configurations  #{ActiveRecord::Base.configurations.inspect}"
    MKItLogger.debug "active_record_base conn_db_config  #{ActiveRecord::Base.connection_db_config.inspect}"
  end

  def self.migrate
    if ActiveRecord::Base.connection.migration_context.needs_migration?
      ActiveRecord::Base.connection.migration_context.migrate
    end
  end

  def self.restore_operation
    MKItLogger.info 'restoring operations...'
    # create interfaces of deployed apps  otherwise haproxy won't start
    Service.all.each do |srv|
      srv.deploy_network
      srv.update_status!
    end
    # daemontools would eventually start haproxy; systemd does not.
    # so, restart here.
    MKItLogger.debug 'restarting proxy...'
    MKIt::HAProxy.restart
  end

  def self.startup(options: {})
    configure(options: options)
    establish_db_connection
    migrate

    MKIt::Initializers.load_default_configs
    MKIt::Interface.up

    System.register(:job_manager, memoize: true) do
      MKIt::JobManager.new
    end
    System.register(:mkit_dns, memoize: true) do
      Thread.new do
        dns = MKIt::DNS.new
        dns.run
      end
    end
    System.register(:docker_listener, memoize: true) do
      MKIt::DockerListener.new
    end
    # watchdog feature is to be re-evaluated
    # System.register(:watchdog, memoize: true) {
    #  MKIt::WatchdogManager.new
    # }

    # register workers
    WorkerManager.register_workers
    SagaManager.register_workers
    System[:job_manager].start
    System[:docker_listener].start
    # watchdog feature is to be re-evaluated
    # System[:watchdog].start
    System[:mkit_dns].run
    restore_operation
    MKItLogger.info 'MKIt is up and running!'
  end
end
