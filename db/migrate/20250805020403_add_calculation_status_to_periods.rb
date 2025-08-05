class AddCalculationStatusToPeriods < ActiveRecord::Migration[8.0]
  def change
    add_column :periods, :calculation_status, :string, default: 'pending'
    add_column :periods, :last_calculated_at, :datetime
    
    add_index :periods, :calculation_status
    add_index :periods, :last_calculated_at
  end
end
