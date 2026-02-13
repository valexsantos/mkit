# frozen_string_literal: true

class CreateVaultSecrets < ActiveRecord::Migration[5.1]
  def up
    create_table :vault_secrets do |t|
      t.string :scope
      t.string :path
      t.string :key
      t.text :value
      t.string :ctype
      t.timestamp :created_at, default: DateTime.now
      t.timestamp :updated_at
    end

    add_index 'vault_secrets', %w[scope path key], unique: true, name: 'vault_secrets_unique'
    add_index 'vault_secrets', %w[scope path], name: 'vault_secrets_path'
  end

  def down
    drop_table :vault_secrets
  end
end
