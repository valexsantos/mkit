# frozen_string_literal: true

class ServicePortsSsl< ActiveRecord::Migration[5.1]
  def up
    add_column :service_ports, :ssl, :string
    add_column :service_ports, :crt, :string
  end
end
