class CreateBusinessProcesses < ActiveRecord::Migration[8.0]
  def change
    create_table :processes, id: :uuid do |t|
      t.string :code
      t.string :name
      t.string :category
      t.text :description
      t.boolean :is_billable
      t.references :hospital, null: false, foreign_key: true, type: :uuid
      t.references :period, null: false, foreign_key: true, type: :uuid
      t.references :activity, null: true, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
