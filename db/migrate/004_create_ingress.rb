# frozen_string_literal: true

class CreateIngress < ActiveRecord::Migration[5.1]
  def up
    create_table :ingresses do |t|
      t.string :service_id
      t.string :version
      t.timestamp :created_at
      t.timestamp :updated_at
    end
  end
end
