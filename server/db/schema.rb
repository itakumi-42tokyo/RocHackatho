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

ActiveRecord::Schema[8.0].define(version: 2026_10_22_110000) do
  create_table "break_requests", force: :cascade do |t|
    t.integer "device_id", null: false
    t.string "kind", null: false
    t.string "body"
    t.string "status", default: "pending", null: false
    t.string "reply"
    t.integer "unlock_minutes"
    t.datetime "responded_at"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id", "status"], name: "index_break_requests_on_device_id_and_status"
    t.index ["device_id"], name: "index_break_requests_on_device_id"
    t.index ["device_id"], name: "index_break_requests_pending_unique", unique: true, where: "status = 'pending'"
  end

  create_table "device_events", force: :cascade do |t|
    t.integer "device_id", null: false
    t.string "kind"
    t.json "payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_device_events_on_device_id"
  end

  create_table "devices", force: :cascade do |t|
    t.string "name", null: false
    t.string "token", null: false
    t.boolean "locked", default: false, null: false
    t.integer "opacity", default: 100, null: false
    t.string "lock_message"
    t.string "lock_mode", default: "full", null: false
    t.string "status", default: "offline", null: false
    t.datetime "last_seen_at"
    t.string "connection_id"
    t.datetime "locked_at"
    t.integer "escape_count", default: 0, null: false
    t.integer "best_escape_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "lock_title", default: "LOCKED", null: false
    t.json "lock_buttons", default: [{"label" => "休憩したい", "kind" => "break"}, {"label" => "トイレ", "kind" => "toilet"}], null: false
    t.integer "token_generation", default: 0, null: false
    t.datetime "unlock_until"
    t.boolean "escaped", default: false, null: false
    t.string "client_id"
    t.index ["client_id"], name: "index_devices_on_client_id", unique: true
    t.index ["token"], name: "index_devices_on_token", unique: true
  end

  add_foreign_key "break_requests", "devices"
  add_foreign_key "device_events", "devices"
end
