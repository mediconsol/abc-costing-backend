class AddCostFieldsToActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :activities, :allocated_cost, :decimal, precision: 15, scale: 2, default: 0
    add_column :activities, :employee_cost, :decimal, precision: 15, scale: 2, default: 0
    add_column :activities, :total_cost, :decimal, precision: 15, scale: 2, default: 0
    add_column :activities, :total_fte, :decimal, precision: 8, scale: 4, default: 0
    add_column :activities, :total_hours, :decimal, precision: 10, scale: 2, default: 0
    add_column :activities, :average_hourly_rate, :decimal, precision: 10, scale: 2, default: 0
    add_column :activities, :unit_cost, :decimal, precision: 10, scale: 4, default: 0
  end
end
