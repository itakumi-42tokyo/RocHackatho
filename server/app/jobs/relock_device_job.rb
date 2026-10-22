# 一時解除の期限（unlock_until）に、端末へ状態を送り直すジョブ。
# 送るのは「今の状態」なので、期限が過ぎていれば実効ロック=true になって自動再ロックされる。
# 延長で unlock_until が先に伸びていれば、まだ解除状態を送るだけで害はない（新しい時刻に別ジョブが入る）。
class RelockDeviceJob < ApplicationJob
  queue_as :default

  def perform(device_id)
    Device.find_by(id: device_id)&.broadcast_state!
  end
end
