# frozen_string_literal: true

class AddProbeSuccessCountToPods < ActiveRecord::Migration[5.1]
  def up
    add_column :pods, :consecutive_readiness_successes, :integer, default: 0
    add_column :pods, :last_health_check_at, :timestamp
  end

  def down
    remove_column :pods, :consecutive_readiness_successes
    remove_column :pods, :last_health_check_at
  end
end
