# Android の WebView が開くロック画面。
# HTML: 初回だけ ?token=… を受け取り、署名付き Cookie を発行してトークン無しの URL に戻す。
#       以降の表示とリクエスト送信は Cookie で端末を特定する。
# JSON: 将来の iOS／ネイティブ描画用。Authorization: Bearer <token> で認証する。
class LockController < ApplicationController
  layout "lock"

  def show
    respond_to do |format|
      format.html { show_html }
      format.json { show_json }
    end
  end

  private

  def show_html
    # トークンが付いていたら Cookie に移し、トークン無しの /lock にリダイレクトする
    if params[:token].present? && (device = Device.find_by(token: params[:token]))
      sign_in_device(device)
      return redirect_to lock_path
    end

    @device = current_lock_device
    @theme = "jail"
    render :show
  end

  def show_json
    device = device_from_bearer
    if device
      render json: device.lock_screen_data
    else
      render json: { error: "unknown token" }, status: :unauthorized
    end
  end
end
