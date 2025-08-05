class CreateDepartments < ActiveRecord::Migration[8.0]
  def change
    create_table :departments, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :hospital_id, null: false
      t.string :period_id, null: false
      t.string :parent_id, null: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :department_type, null: false
      t.string :manager
      t.text :description

      t.timestamps
    end
    
    add_index :departments, [:hospital_id, :period_id, :code], unique: true
    add_index :departments, [:hospital_id, :period_id]
    add_index :departments, :department_type
    add_foreign_key :departments, :hospitals
    add_foreign_key :departments, :periods
    add_foreign_key :departments, :departments, column: :parent_id
  end
end
