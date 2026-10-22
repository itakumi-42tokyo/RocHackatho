# 5 秒ごとに実行し、ハートビートが途絶えた端末の状態を更新する。
# 状態が変わったときだけ保存する（無駄な broadcast を出さない）。
class DeviceStatusSweepJob < ApplicationJob
  queue_as :default

  def perform
    now = Time.current

    Device.where.not(status: "offline").find_each do |device|
      last = device.last_seen_at
      next if last.nil?

      age = now - last
      new_status =
        if age > Device::OFFLINE_AFTER then "offline"
        elsif age > Device::INACTIVE_AFTER then "inactive"
        else next
        end

      next if device.status == new_status

      was_locked = device.effective_locked? # 一時解除中は脱獄に数えない
      device.update!(status: new_status)
      device.log_event(new_status)
      # ロック中に音信不通 = 脱獄（mark_escaped! 側で状態変化1回につき1回に抑える）
      if was_locked && new_status == "offline"
        Rails.logger.info("[jail] sweep offline device=#{device.id} effective_locked=#{was_locked}")
        device.mark_escaped!
      end
    end
  end
end
