class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.belongs_to :hunt, null: false, foreign_key: true
      t.string :user_id, null: false
      t.string :content, null: false

      t.timestamps
    end
  end
end
