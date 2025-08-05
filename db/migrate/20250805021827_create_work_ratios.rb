class CreateWorkRatios < ActiveRecord::Migration[8.0]
  def change
    create_table :work_ratios, id: :uuid do |t|
      t.decimal :ratio
      t.decimal :hours_per_period
      t.references :hospital, null: false, foreign_key: true, type: :uuid
      t.references :period, null: false, foreign_key: true, type: :uuid
      t.references :employee, null: false, foreign_key: true, type: :uuid
      t.references :activity, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
