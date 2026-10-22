class CreateBreakRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :break_requests do |t|
      t.references :device, null: false, foreign_key: true
      t.string :kind, null: false                       # break / toilet / help / custom
      t.string :body                                    # custom の自由入力など（任意）
      t.string :status, null: false, default: "pending" # pending / approved / denied / expired / cancelled
      t.string :reply                                   # 管理者からの返答（フェーズ3で使う）
      t.integer :unlock_minutes                         # 承認時の解除分数（フェーズ4で使う）
      t.datetime :responded_at                          # 承認・却下・取り消し・期限切れの時刻
      t.datetime :expires_at, null: false               # 承認待ちのまま期限切れになる時刻

      t.timestamps
    end

    add_index :break_requests, [:device_id, :status]
  end
end
