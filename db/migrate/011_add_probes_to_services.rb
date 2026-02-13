# frozen_string_literal: true

class AddProbesToServices < ActiveRecord::Migration[5.1]
  def up
    add_column :services, :liveness_probe, :text
    add_column :services, :readiness_probe, :text
  end

  def down
    remove_column :services, :liveness_probe
    remove_column :services, :readiness_probe
  end
end
