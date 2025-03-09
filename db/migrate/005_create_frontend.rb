# frozen_string_literal: true

class CreateFrontend < ActiveRecord::Migration[5.1]
  def up
    create_table :frontends do |t|
      t.string :ingress_id
      t.string :name
      t.string :mode
      t.string :port
      t.string :ssl
      t.string :crt
      t.text :options, default: '[]'
      t.text :bind_options, default: '[]'
      t.text :default_backend
      t.string :version
      t.timestamp :created_at
      t.timestamp :updated_at
    end
  end
end
