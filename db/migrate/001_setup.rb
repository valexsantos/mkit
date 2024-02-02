# frozen_string_literal: true

class Setup < ActiveRecord::Migration[5.1]
  def up
    create_table :services do |t|
      t.string :name
      t.string :image
      t.string :qdm
      t.string :command
      t.integer :max_replicas, default: 1
      t.integer :min_replicas, default: 1
      t.string :lease_id # ip config
      t.string :pods_network, default: 'mkit' # docker network bridge|specific
      t.integer :version # active version - later
      t.string :status
      t.timestamp :created_at, default: DateTime.now
      t.timestamp :updated_at
    end

    add_index 'services', ['name'], name: 'services_name_id'

    create_table :service_configs do |t|
      t.string :service_id
      t.string :key
      t.string :value
      t.string :ctype # docker_param|env|volume?|....
      t.integer :version
    end

    create_table :pods do |t|
      t.string :service_id
      t.string :pod_id
      t.string :name
      t.string :ip
      t.string :image
      t.string :status
      t.integer :version
    end

    create_table :volumes do |t|
      t.string :service_id
      t.string :name
      t.string :path
      t.string :ctype # docker|local....
      t.string :status
      t.integer :version
    end

    create_table :service_ports do |t|
      t.string :service_id
      t.string :internal_port
      t.string :external_port
      t.string :mode # tcp | http
      t.string :load_bal
      t.integer :version
    end

    create_table :pools do |t|
      t.string :name
      t.string :ip
      t.string :range
      t.string :netmask
      t.string :status # in_use|exausted
      t.boolean :preferred, default: false
    end

    create_table :leases do |t|
      t.string :pool_id
      t.string :service_id
      t.string :interface_name
      t.string :interface_type # tun|tap
      t.string :status # reserved|in_use|expired|deleted|....
      t.string :ip
      t.timestamp :expires_at
    end

    create_table :dns_hosts do |t|
      t.string :service_id
      t.string :pod_id
      t.string :name # fqdn
      t.string :ip
      t.string :ipv6
    end

    # mkit configs
    # e.g.
    #   default network pool
    #   rabbitmq address
    #   haproxy
    #     config.d path
    #     reload command - pq quero usar o daemontools
    #     stop
    #     start
    #     status
    #
    create_table :settings do |t|
      t.string :key
      t.string :value
    end
  end

  def down
    drop_table :services
  end
end
