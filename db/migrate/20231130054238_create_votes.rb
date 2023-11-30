class CreateVotes < ActiveRecord::Migration[7.1]
  def change
    create_table :votes do |t|
      t.belongs_to :submission, null: false, foreign_key: true
      t.string :user_id, null: false
      t.string :value

      t.timestamps
    end

    add_index :votes, [:submission_id, :user_id], unique: true
  end
end
