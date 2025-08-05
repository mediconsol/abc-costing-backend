class AddCostFieldsToProcesses < ActiveRecord::Migration[8.0]
  def change
    add_column :processes, :allocated_cost, :decimal, precision: 15, scale: 2, default: 0
    add_column :processes, :total_cost, :decimal, precision: 15, scale: 2, default: 0
    add_column :processes, :unit_cost, :decimal, precision: 10, scale: 4, default: 0
    add_column :processes, :profit_margin, :decimal, precision: 8, scale: 4, default: 0
  end
end
