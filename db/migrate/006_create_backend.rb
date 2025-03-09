# frozen_string_literal: true

class CreateBackend < ActiveRecord::Migration[5.1]
  def up
    create_table :backends do |t|
      t.string :ingress_id
      t.string :name
      t.string :mode
      t.string :load_bal
      t.string :port
      t.text :options, default: '[]'
      t.text :bind_options, default: '[]'
      t.string :version
      t.timestamp :created_at
      t.timestamp :updated_at
    end
  end
end
