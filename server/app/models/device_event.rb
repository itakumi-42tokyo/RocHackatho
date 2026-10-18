class DeviceEvent < ApplicationRecord
  belongs_to :device

  scope :recent, -> { order(created_at: :desc) }

  # 発生したら管理画面のログ先頭に差し込む
  after_create_commit do
    broadcast_prepend_to "admin", target: "events", partial: "admin/event", locals: { event: self }
  end

  # 管理画面のログに出す一言
  def summary
    case kind
    when "lock"     then "🔒 ロック（#{payload["mode"]}）"
    when "unlock"   then "🔓 解除"
    when "escaped"  then "🚨 脱獄（#{payload["seconds"]}秒）"
    when "online"   then "🟢 オンライン"
    when "inactive" then "🟡 反応なし"
    when "offline"  then "⚫ オフライン"
    else kind
    end
  end
end
