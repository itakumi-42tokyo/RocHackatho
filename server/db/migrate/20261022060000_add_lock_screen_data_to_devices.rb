class AddLockScreenDataToDevices < ActiveRecord::Migration[8.0]
  def change
    add_column :devices, :lock_title, :string, null: false, default: "LOCKED"
    # ロック画面のボタン（最大2つ。将来の iOS シールドの制約に合わせる）。[{label, kind}]
    add_column :devices, :lock_buttons, :json, null: false, default: [
      { "label" => "休憩したい", "kind" => "break" },
      { "label" => "トイレ", "kind" => "toilet" }
    ]
  end
end
