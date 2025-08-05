class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :hospital_id, null: false
      t.string :period_id, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.string :category, null: false
      t.boolean :is_direct, default: false
      t.text :description

      t.timestamps
    end
    
    add_index :accounts, [:hospital_id, :period_id, :code], unique: true
    add_index :accounts, [:hospital_id, :period_id]
    add_index :accounts, :category
    add_index :accounts, :is_direct
    add_foreign_key :accounts, :hospitals
    add_foreign_key :accounts, :periods
  end
end
