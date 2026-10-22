require "securerandom"

# Android 端末ごとのチャンネル。
# サーバー → 端末へは「現在の状態」を送るだけ（命令ではない）。端末 → サーバーへはハートビートと報告。
class DeviceChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_device

    @conn_id = SecureRandom.uuid
    was_online = current_device.online?
    stream_for current_device
    current_device.update!(connection_id: @conn_id, status: "online", last_seen_at: Time.current)
    current_device.log_event("online") unless was_online

    # つながった直後に、今の状態をこの端末へ送る（取りこぼし・再接続に強くする）
    transmit current_device.state_payload
  end

  # 3 秒ごとに届く生存通知
  def heartbeat(_data = {})
    return unless current_device

    current_device.update_columns(last_seen_at: Time.current)
    unless current_device.online?
      current_device.update!(status: "online")
      current_device.log_event("online")
    end
  end

  # Android が「覆いが実際に出ているか」を報告する。ロック中なのに出ていない = 脱獄。
  # 接続は長命で current_device は古くなるので、判定前に必ず最新状態を読み直す。
  def report(data)
    return unless current_device

    current_device.reload
    shown = data["overlay_shown"]
    Rails.logger.info("[jail] report device=#{current_device.id} overlay_shown=#{shown} effective_locked=#{current_device.effective_locked?} escaped=#{current_device.escaped?}")

    return unless current_device.effective_locked?

    if shown == false
      current_device.mark_escaped!
    else
      current_device.mark_recaptured! # 覆いが戻った
    end
  end

  def unsubscribed
    return unless current_device

    # この接続が今の接続のときだけ offline にする（古い接続が後から閉じても誤判定しない）
    if current_device.reload.connection_id == @conn_id
      was_locked = current_device.effective_locked?
      current_device.update!(status: "offline")
      current_device.log_event("offline")
      Rails.logger.info("[jail] unsubscribed device=#{current_device.id} effective_locked=#{was_locked}")
      current_device.mark_escaped! if was_locked
    end
  end
end
