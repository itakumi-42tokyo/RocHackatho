class DeviceEvent < ApplicationRecord
  belongs_to :device

  scope :recent, -> { order(created_at: :desc) }

  # 発生したら管理画面を Turbo 8 のページリフレッシュ（morph）で更新する
  after_create_commit -> { broadcast_refresh_to "admin" }

  # 管理画面のログに出す一言
  def summary
    case kind
    when "lock"     then "🔒 ロック（#{payload["mode"]}）"
    when "unlock"   then "🔓 解除"
    when "escaped"  then "🚨 脱獄（#{payload["seconds"]}秒）"
    when "online"   then "🟢 オンライン"
    when "inactive" then "🟡 反応なし"
    when "offline"  then "⚫ オフライン"
    when "recaptured" then "⛓ 連れ戻し"
    else kind
    end
  end
end
