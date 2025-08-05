class CreatePeriods < ActiveRecord::Migration[8.0]
  def change
    create_table :periods, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :hospital_id, null: false
      t.string :name, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.boolean :is_active, default: false

      t.timestamps
    end
    
    add_index :periods, [:hospital_id, :name], unique: true
    add_index :periods, [:hospital_id, :is_active]
    add_foreign_key :periods, :hospitals
  end
end
