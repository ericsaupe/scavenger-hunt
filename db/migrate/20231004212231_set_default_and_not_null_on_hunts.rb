class SetDefaultAndNotNullOnHunts < ActiveRecord::Migration[7.0]
  def change
    Hunt.where(lock_results: nil).update_all(lock_results: false)
    Hunt.where(password_entered: nil).update_all(password_entered: false)

    change_column :hunts, :lock_results, :boolean, default: false, null: false
    change_column :hunts, :password_entered, :boolean, default: false, null: false
  end
end
