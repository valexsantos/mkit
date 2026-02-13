# frozen_string_literal: true

class AddValidationErrorToServices < ActiveRecord::Migration[5.1]
  def up
    add_column :services, :validation_errors, :text
  end

  def down
    remove_column :services, :validation_errors
  end
end
