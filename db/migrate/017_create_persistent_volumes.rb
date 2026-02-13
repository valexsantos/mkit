# frozen_string_literal: true

class CreatePersistentVolumes < ActiveRecord::Migration[5.1]
  def up
    create_table :persistent_volumes do |t|
      t.string :name
      t.string :capacity
      t.string :reclaim_policy, default: 'Retain'
      t.string :storage_class, default: 'default'
      t.string :status, default: 'Available'
      t.string :volume_mode, default: 'Filesystem'
      t.text :mount_options
      t.text :annotations
      t.timestamp :created_at, default: DateTime.now
      t.timestamp :updated_at
    end

    add_index 'persistent_volumes', ['name'], unique: true, name: 'pv_name_unique'
    add_index 'persistent_volumes', ['status'], name: 'pv_status'
  end

  def down
    drop_table :persistent_volumes
  end
end
