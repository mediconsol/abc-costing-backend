class AddCalculationFieldsToPeriods < ActiveRecord::Migration[8.0]
  def change
    add_column :periods, :calculation_started_at, :datetime
    add_column :periods, :calculation_completed_at, :datetime
    add_column :periods, :calculation_error, :text
  end
end
