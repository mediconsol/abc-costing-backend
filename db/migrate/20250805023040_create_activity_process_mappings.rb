class CreateActivityProcessMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_process_mappings, id: :uuid do |t|
      t.decimal :rate, precision: 10, scale: 4, default: 0
      t.references :hospital, null: false, foreign_key: true, type: :uuid
      t.references :period, null: false, foreign_key: true, type: :uuid
      t.references :activity, null: false, foreign_key: true, type: :uuid
      t.references :process, null: false, foreign_key: true, type: :uuid
      t.references :driver, null: true, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
