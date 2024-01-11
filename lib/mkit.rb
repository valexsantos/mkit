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
require_relative "mkit/version"
require_relative 'mkit/mkit_interface'
require_relative 'mkit/mkit_dns'
require_relative 'mkit/docker_listener'
require 'mkit/app/helpers/haproxy'
require 'mkit/app/controllers/services_controller'
require 'mkit/app/controllers/mkitjobs_controller'
require 'mkit/mkit_interface'
require 'mkit/mkit_dns'
require 'mkit/job_manager'
require 'mkit/workers/worker_manager'
require 'mkit/sagas/saga_manager'
require 'mkit/docker_listener'
require 'mkit/app/helpers/haproxy'
require 'active_record/tasks/database_tasks'
require 'mkit/utils'

MKItLogger = Console.logger

module MKIt
  class Error < StandardError; end
  include ActiveRecord::Tasks

  System = Dry::Container.new

  def self.configure(options:)
    @root = MKIt::Utils.root
    MKItLogger.debug!
    #
    # config dir
    if ENV["RACK_ENV"] != "development"
      @config_dir = options[:config_dir].nil? ? '/etc/mkit' : options[:config_dir]
    else
      @config_dir = options[:config_dir].nil? ? "#{@root}/config" : options[:config_dir]
    end
    MKIt::Utils.set_config_dir(@config_dir)
    # create dirs
    if ENV["RACK_ENV"] != "development" || !options[:config_dir].nil?
      check_config_files = false
      if ! File.exists?(@config_dir)
        FileUtils.mkdir_p(@config_dir)
        check_config_files = true
      end
      FileUtils.mkdir_p('/var/lib/mkitd') unless File.exists?('/var/lib/mkitd')
      FileUtils.cp( "#{@root}/config/mkit_config.yml", @config_dir) unless File.exists?("#{@config_dir}/mkit_config.yml")
      FileUtils.cp( "#{@root}/config/database.yml", @config_dir) unless File.exists?("#{@config_dir}/database.yml")
      FileUtils.cp( "#{@root}/config/mkitd_config.sh", @config_dir) unless File.exists?("#{@config_dir}/mkitd_config.sh")
      if check_config_files
        MKItLogger.info "Configuration files copied to #{@config_dir}. Please check it and restart."
        exit
      end
    end
    #
    # load configuration
    MKIt::Initializers.load_my_configuration
    #
    # run config based tasks
    FileUtils.mkdir_p(MKIt::Config.mkit.haproxy.config_dir)
    # ...haproxy defaults file
    FileUtils.cp(
      "#{MKIt::Utils.root}/lib/mkit/app/templates/haproxy/0000_defaults.cfg",
      MKIt::Config.mkit.haproxy.config_dir
    ) unless File.exists?("#{MKIt::Config.mkit.haproxy.config_dir}/0000_defaults.cfg")
    #
    #  conn = { adapter: "sqlite3", database: ":memory:" }
    #  ActiveRecord::Base.establish_connection(conn)
    #  include ActiveRecord::Tasks
    #  DatabaseTasks.database_configuration = YAML.load_file('my_database_config.yml')
    #  DatabaseTasks.db_dir = 'db'
    #
    DatabaseTasks.database_configuration = MKIt::Utils.load_db_config
    DatabaseTasks.env=MKIt::Config.mkit.database.env
    DatabaseTasks.migrations_paths=[ "#{@root}/db/migrate" ]
    DatabaseTasks.db_dir="db"
    DatabaseTasks.root=@root
  end

  def self.establish_db_connection
    #
    ActiveRecord::Base.establish_connection(DatabaseTasks.database_configuration[DatabaseTasks.env])
    ActiveRecord::Base.connection.migration_context.migrations_paths.clear
    ActiveRecord::Base.connection.migration_context.migrations_paths << "#{@root}/db/migrate"
    #
    MKItLogger.debug "database_tasks migration paths     #{DatabaseTasks.migrations_paths}"
    MKItLogger.debug "active_record_base migration_paths #{ActiveRecord::Base.connection.migration_context.migrations_paths.inspect}"
    MKItLogger.debug "active_record_base configurations  #{ActiveRecord::Base.configurations.inspect}"
    MKItLogger.debug "active_record_base conn_db_config  #{ActiveRecord::Base.connection_db_config.inspect}"
  end

  def self.migrate
    ActiveRecord::Base.connection.migration_context.migrate if ActiveRecord::Base.connection.migration_context.needs_migration?
  end

  def self.restore_operation
    MKItLogger.info "restoring operations..."
    # create interfaces of deployed apps  otherwise haproxy won't start
    Service.all.each { | srv |
      srv.deploy_network
      srv.update_status!
    }
  end

  def self.startup(options: {})
    self.configure(options: options)
    self.establish_db_connection
    self.migrate

    MKIt::Initializers.load_default_configs
    MKIt::Interface.up

    System.register(:job_manager, memoize: true) {
      MKIt::JobManager.new
    }
    System.register(:mkit_dns, memoize: true) {
      Thread.new {
        dns = MKIt::DNS.new
        dns.run
      }
    }
    System.register(:docker_listener, memoize: true) {
      MKIt::DockerListener.new
    }
    # watchdog feature is to be re-evaluated
    # System.register(:watchdog, memoize: true) {
    #  MKIt::WatchdogManager.new
    # }

    # register workers
    WorkerManager.register_workers    
    SagaManager.register_workers
    #
    System[:job_manager].start
    System[:docker_listener].start
    # watchdog feature is to be re-evaluated
    # System[:watchdog].start
    System[:mkit_dns].run
    #
    self.restore_operation
    #
    MKItLogger.debug "restarting proxy..."
    MKIt::HAProxy.restart
    MKItLogger.info "MKIt is up and running!"
  end

end

