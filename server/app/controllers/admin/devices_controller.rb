class Admin::DevicesController < Admin::BaseController
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

  def lock_all
    Device.find_each { |d| d.lock!(mode: params[:lock_mode].presence) }
    redirect_to admin_root_path
  end

  def unlock_all
    Device.where(locked: true).find_each(&:unlock!)
    redirect_to admin_root_path
  end
end
