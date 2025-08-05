class CreateDrivers < ActiveRecord::Migration[8.0]
  def change
    create_table :drivers, id: :uuid do |t|
      t.string :code
      t.string :name
      t.string :driver_type
      t.string :category
      t.string :unit
      t.text :description
      t.boolean :is_active
      t.references :hospital, null: false, foreign_key: true, type: :uuid
      t.references :period, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
