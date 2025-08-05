class CreateHospitals < ActiveRecord::Migration[8.0]
  def change
    create_table :hospitals, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :name, null: false
      t.text :address
      t.string :phone
      t.string :hospital_type

      t.timestamps
    end
    
    add_index :hospitals, :name
  end
end
