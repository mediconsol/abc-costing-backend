class CreateEmployees < ActiveRecord::Migration[8.0]
  def change
    create_table :employees, id: :uuid do |t|
      t.string :employee_id
      t.string :name
      t.string :email
      t.string :position
      t.decimal :hourly_rate
      t.decimal :annual_salary
      t.decimal :fte
      t.boolean :is_active
      t.references :hospital, null: false, foreign_key: true, type: :uuid
      t.references :period, null: false, foreign_key: true, type: :uuid
      t.references :department, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
