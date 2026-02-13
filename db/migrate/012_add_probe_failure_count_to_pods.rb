# frozen_string_literal: true

class AddProbeFailureCountToPods < ActiveRecord::Migration[5.1]
  def up
    add_column :pods, :consecutive_liveness_failures, :integer, default: 0
    add_column :pods, :consecutive_readiness_failures, :integer, default: 0
  end

  def down
    remove_column :pods, :consecutive_liveness_failures
    remove_column :pods, :consecutive_readiness_failures
  end
end
