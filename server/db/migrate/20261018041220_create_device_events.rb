class CreateDeviceEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :device_events do |t|
      t.references :device, null: false, foreign_key: true
      t.string :kind
      t.json :payload

      t.timestamps
    end
  end
end
