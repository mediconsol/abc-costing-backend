class CreateRevenueCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :revenue_codes, id: :uuid do |t|
      t.string :code
      t.string :name
      t.string :category
      t.decimal :price
      t.text :description
      t.boolean :is_active
      t.references :hospital, null: false, foreign_key: true, type: :uuid
      t.references :period, null: false, foreign_key: true, type: :uuid
      t.references :process, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
