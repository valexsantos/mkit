# frozen_string_literal: true

class MkitJobs < ActiveRecord::Migration[5.1]
  def up
    create_table :mkit_jobs do |t|
      t.string :topic
      t.string :service_id
      t.string :pod_id
      t.string :status
      t.string :retries
      t.string :payload
      t.timestamp :created_at
      t.timestamp :updated_at
    end
  end
end
