# 再ロックの取りこぼし対策。予約した RelockDeviceJob が失われても（サーバー再起動など）、
# 期限切れの一時解除を拾って再ロックを確定する。定期実行する。
# unlock_until を消すと device_facing_change? が効いて端末へ状態が送り直される。
class RelockSweepJob < ApplicationJob
  queue_as :default

  def perform
    Device.where(locked: true)
          .where.not(unlock_until: nil)
          .where(unlock_until: ..Time.current)
          .find_each { |device| device.update!(unlock_until: nil) }
  end
end
