# frozen_string_literal: true

class AddScalingToResources < ActiveRecord::Migration[5.1]
  def up
    add_column :resources, :target_cpu_percent, :integer
    add_column :resources, :target_memory_percent, :integer
    add_column :resources, :scale_up_stabilization, :integer, default: 0
    add_column :resources, :scale_down_stabilization, :integer, default: 0
    add_column :resources, :last_scale_up_at, :timestamp
    add_column :resources, :last_scale_down_at, :timestamp
  end

  def down
    remove_column :resources, :target_cpu_percent
    remove_column :resources, :target_memory_percent
    remove_column :resources, :scale_up_stabilization
    remove_column :resources, :scale_down_stabilization
    remove_column :resources, :last_scale_up_at
    remove_column :resources, :last_scale_down_at
  end
end
