# frozen_string_literal: true

class AddCapturedAtToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :captured_at, :datetime
  end
end
