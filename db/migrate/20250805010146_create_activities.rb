class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :hospital_id, null: false
      t.string :period_id, null: false
      t.string :department_id, null: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :category, null: false
      t.text :description

      t.timestamps
    end
    
    add_index :activities, [:hospital_id, :period_id, :code], unique: true
    add_index :activities, [:hospital_id, :period_id]
    add_index :activities, :category
    add_foreign_key :activities, :hospitals
    add_foreign_key :activities, :periods
    add_foreign_key :activities, :departments
  end
end
