class CreateDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :devices do |t|
      t.string :name, null: false
      t.string :token, null: false
      t.boolean :locked, null: false, default: false
      t.integer :opacity, null: false, default: 100
      t.string :lock_message
      t.string :lock_mode, null: false, default: "full"   # overlay / pinning / full
      t.string :status, null: false, default: "offline"   # online / inactive / offline
      t.datetime :last_seen_at
      t.string :connection_id
      t.datetime :locked_at
      t.integer :escape_count, null: false, default: 0
      t.integer :best_escape_seconds

      t.timestamps
    end
    add_index :devices, :token, unique: true
  end
end
