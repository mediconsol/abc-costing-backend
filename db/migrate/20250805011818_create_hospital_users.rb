class CreateHospitalUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :hospital_users, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :user_id, null: false
      t.string :hospital_id, null: false
      t.string :role, null: false, default: 'viewer'

      t.timestamps
    end
    
    add_index :hospital_users, [:user_id, :hospital_id], unique: true
    add_index :hospital_users, :user_id
    add_index :hospital_users, :hospital_id
    add_index :hospital_users, :role
    
    add_foreign_key :hospital_users, :users
    add_foreign_key :hospital_users, :hospitals
  end
end
