class Admin::DevicesController < Admin::BaseController
  # ロック画面のボタン構成のプリセット（全員操作で選ぶ）
  BUTTON_PRESETS = {
    "break_toilet" => [{ "label" => "休憩したい", "kind" => "break" }, { "label" => "トイレ", "kind" => "toilet" }],
    "break_custom" => [{ "label" => "休憩したい", "kind" => "break" }, { "label" => "その他", "kind" => "custom" }],
    "toilet_only"  => [{ "label" => "トイレ", "kind" => "toilet" }],
    "none"         => []
  }.freeze

  def index
    @devices = Device.recent.to_a
    @events = DeviceEvent.recent.limit(30).includes(:device)
  end

  def update
    device = Device.find(params[:id])
    if params[:commit_action] == "unlock"
      device.unlock!
    else
      device.lock!(
        mode: params.dig(:device, :lock_mode),
        opacity: params.dig(:device, :opacity),
        message: params.dig(:device, :lock_message)
      )
    end
    respond_to do |format|
      format.turbo_stream { head :no_content } # 画面は broadcast で更新される
      format.html { redirect_to admin_root_path }
    end
  end

  # 一時解除を延長し、新しい期限に再ロックジョブを予約し直す
  def extend_unlock
    device = Device.find(params[:id])
    device.extend_unlock!(params[:minutes])
    RelockDeviceJob.set(wait_until: device.unlock_until).perform_later(device.id)
    respond_back
  end

  # 今すぐ再ロックする
  def relock
    Device.find(params[:id]).relock_now!
    respond_back
  end

  def lock_all
    Device.find_each { |d| d.lock!(mode: params[:lock_mode].presence) }
    redirect_to admin_root_path
  end

  def unlock_all
    Device.where(locked: true).find_each(&:unlock!)
    redirect_to admin_root_path
  end

  # 全員の lock_title / lock_buttons を一括で設定する
  def update_lock_screen
    title = params[:lock_title]
    buttons = BUTTON_PRESETS[params[:buttons_preset]]

    Device.find_each do |device|
      attrs = {}
      attrs[:lock_title] = title.presence || "LOCKED" if params.key?(:lock_title)
      attrs[:lock_buttons] = buttons unless buttons.nil?
      device.update!(attrs) if attrs.any?
    end
    redirect_to admin_root_path
  end

  private

  # 画面は broadcast（管理画面の morph リフレッシュ）で更新されるので、ここは何も描かない
  def respond_back
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to admin_root_path }
    end
  end
end
