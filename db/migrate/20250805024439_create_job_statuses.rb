class CreateJobStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :job_statuses, id: :uuid do |t|
      t.string :job_id, null: false
      t.string :job_type, null: false
      t.string :status, default: 'pending', null: false
      t.text :progress_message
      t.text :error_message
      t.text :result
      t.integer :total_steps
      t.integer :completed_steps
      t.datetime :started_at
      t.datetime :completed_at
      t.references :hospital, null: false, foreign_key: true, type: :uuid
      t.references :period, null: true, foreign_key: true, type: :uuid
      t.references :user, null: true, foreign_key: true, type: :uuid

      t.timestamps
    end
    
    add_index :job_statuses, :job_id, unique: true
    add_index :job_statuses, [:hospital_id, :job_type]
    add_index :job_statuses, :status
    add_index :job_statuses, :created_at
  end
end
