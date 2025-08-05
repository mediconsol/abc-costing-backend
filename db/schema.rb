# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_05_024711) do
  create_table "accounts", id: :string, force: :cascade do |t|
    t.string "hospital_id", null: false
    t.string "period_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.string "category", null: false
    t.boolean "is_direct", default: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_accounts_on_category"
    t.index ["hospital_id", "period_id", "code"], name: "index_accounts_on_hospital_id_and_period_id_and_code", unique: true
    t.index ["hospital_id", "period_id"], name: "index_accounts_on_hospital_id_and_period_id"
    t.index ["is_direct"], name: "index_accounts_on_is_direct"
  end

  create_table "activities", id: :string, force: :cascade do |t|
    t.string "hospital_id", null: false
    t.string "period_id", null: false
    t.string "department_id"
    t.string "code", null: false
    t.string "name", null: false
    t.string "category", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "allocated_cost", precision: 15, scale: 2, default: "0.0"
    t.decimal "employee_cost", precision: 15, scale: 2, default: "0.0"
    t.decimal "total_cost", precision: 15, scale: 2, default: "0.0"
    t.decimal "total_fte", precision: 8, scale: 4, default: "0.0"
    t.decimal "total_hours", precision: 10, scale: 2, default: "0.0"
    t.decimal "average_hourly_rate", precision: 10, scale: 2, default: "0.0"
    t.decimal "unit_cost", precision: 10, scale: 4, default: "0.0"
    t.index ["category"], name: "index_activities_on_category"
    t.index ["hospital_id", "period_id", "code"], name: "index_activities_on_hospital_id_and_period_id_and_code", unique: true
    t.index ["hospital_id", "period_id"], name: "index_activities_on_hospital_id_and_period_id"
  end

# Could not dump table "activity_process_mappings" because of following StandardError
#   Unknown type 'uuid' for column 'id'


  create_table "departments", id: :string, force: :cascade do |t|
    t.string "hospital_id", null: false
    t.string "period_id", null: false
    t.string "parent_id"
    t.string "code", null: false
    t.string "name", null: false
    t.string "department_type", null: false
    t.string "manager"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_type"], name: "index_departments_on_department_type"
    t.index ["hospital_id", "period_id", "code"], name: "index_departments_on_hospital_id_and_period_id_and_code", unique: true
    t.index ["hospital_id", "period_id"], name: "index_departments_on_hospital_id_and_period_id"
  end

# Could not dump table "drivers" because of following StandardError
#   Unknown type 'uuid' for column 'id'


# Could not dump table "employees" because of following StandardError
#   Unknown type 'uuid' for column 'id'


  create_table "hospital_users", id: :string, force: :cascade do |t|
    t.string "user_id", null: false
    t.string "hospital_id", null: false
    t.string "role", default: "viewer", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hospital_id"], name: "index_hospital_users_on_hospital_id"
    t.index ["role"], name: "index_hospital_users_on_role"
    t.index ["user_id", "hospital_id"], name: "index_hospital_users_on_user_id_and_hospital_id", unique: true
    t.index ["user_id"], name: "index_hospital_users_on_user_id"
  end

  create_table "hospitals", id: :string, force: :cascade do |t|
    t.string "name", null: false
    t.text "address"
    t.string "phone"
    t.string "hospital_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_hospitals_on_name"
  end

# Could not dump table "job_statuses" because of following StandardError
#   Unknown type 'uuid' for column 'id'


  create_table "jwt_denylists", id: :string, force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exp"], name: "index_jwt_denylists_on_exp"
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "periods", id: :string, force: :cascade do |t|
    t.string "hospital_id", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.boolean "is_active", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "calculation_status", default: "pending"
    t.datetime "last_calculated_at"
    t.datetime "calculation_started_at"
    t.datetime "calculation_completed_at"
    t.text "calculation_error"
    t.index ["calculation_status"], name: "index_periods_on_calculation_status"
    t.index ["hospital_id", "is_active"], name: "index_periods_on_hospital_id_and_is_active"
    t.index ["hospital_id", "name"], name: "index_periods_on_hospital_id_and_name", unique: true
    t.index ["last_calculated_at"], name: "index_periods_on_last_calculated_at"
  end

# Could not dump table "processes" because of following StandardError
#   Unknown type 'uuid' for column 'id'


# Could not dump table "revenue_codes" because of following StandardError
#   Unknown type 'uuid' for column 'id'


  create_table "users", id: :string, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

# Could not dump table "work_ratios" because of following StandardError
#   Unknown type 'uuid' for column 'id'


  add_foreign_key "accounts", "hospitals"
  add_foreign_key "accounts", "periods"
  add_foreign_key "activities", "departments"
  add_foreign_key "activities", "hospitals"
  add_foreign_key "activities", "periods"
  add_foreign_key "activity_process_mappings", "activities"
  add_foreign_key "activity_process_mappings", "drivers"
  add_foreign_key "activity_process_mappings", "hospitals"
  add_foreign_key "activity_process_mappings", "periods"
  add_foreign_key "activity_process_mappings", "processes"
  add_foreign_key "departments", "departments", column: "parent_id"
  add_foreign_key "departments", "hospitals"
  add_foreign_key "departments", "periods"
  add_foreign_key "drivers", "hospitals"
  add_foreign_key "drivers", "periods"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "hospitals"
  add_foreign_key "employees", "periods"
  add_foreign_key "hospital_users", "hospitals"
  add_foreign_key "hospital_users", "users"
  add_foreign_key "job_statuses", "hospitals"
  add_foreign_key "job_statuses", "periods"
  add_foreign_key "job_statuses", "users"
  add_foreign_key "periods", "hospitals"
  add_foreign_key "processes", "activities"
  add_foreign_key "processes", "hospitals"
  add_foreign_key "processes", "periods"
  add_foreign_key "revenue_codes", "hospitals"
  add_foreign_key "revenue_codes", "periods"
  add_foreign_key "revenue_codes", "processes"
  add_foreign_key "work_ratios", "activities"
  add_foreign_key "work_ratios", "employees"
  add_foreign_key "work_ratios", "hospitals"
  add_foreign_key "work_ratios", "periods"
end
