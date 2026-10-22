# Android の WebView が開くロック画面。token で端末を特定する。
# 同じ内容を JSON でも返す（将来の iOS／ネイティブ描画用）。
class LockController < ApplicationController
  layout "lock"

  def show
    @device = Device.find_by(token: params[:token])
    @theme = "jail"
    respond_to do |format|
      format.html
      format.json do
        if @device
          render json: @device.lock_screen_data
        else
          render json: { error: "unknown token" }, status: :not_found
        end
      end
    end
  end
end
