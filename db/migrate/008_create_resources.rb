# frozen_string_literal: true

class CreateResources < ActiveRecord::Migration[5.1]
  def up
    create_table :resources do |t|
      t.string :service_id
      t.string :version
      t.integer :min_replicas, default: 1
      t.integer :max_replicas, default: 1
      t.string :cpu_limits
      t.string :memory_limits
      t.string :memory_swap_limits
      t.timestamp :created_at
      t.timestamp :updated_at
    end
  end
end
