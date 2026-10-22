class AddEscapedAndClientIdToDevices < ActiveRecord::Migration[8.0]
  def change
    # 「今この端末が脱獄中か」。脱獄は状態変化1回につき1回だけ数えるためのフラグ
    add_column :devices, :escaped, :boolean, default: false, null: false

    # 端末の実体を表す ID（Android の ANDROID_ID）。再インストールでも同じ端末として扱う。
    # NULL は SQLite では一意制約の対象外なので、既存端末（nil）が複数あっても問題ない。
    add_column :devices, :client_id, :string
    add_index :devices, :client_id, unique: true
  end
end
