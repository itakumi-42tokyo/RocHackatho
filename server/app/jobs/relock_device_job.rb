# 一時解除の期限（unlock_until）に、端末へ状態を送り直すジョブ。
# ・期限が過ぎていれば unlock_until を消して「再ロック」を確定する
# ・延長で unlock_until が未来に伸びていれば、まだ解除状態を送るだけ（強制ロックしない）
# どちらでも「今の状態」を送るので、取りこぼしても次の送信や再接続で追いつく。
class RelockDeviceJob < ApplicationJob
  queue_as :default

  def perform(device_id)
    device = Device.find_by(id: device_id)
    return unless device

    device.update!(unlock_until: nil) if device.unlock_until&.past?
    device.broadcast_state!
  end
end
