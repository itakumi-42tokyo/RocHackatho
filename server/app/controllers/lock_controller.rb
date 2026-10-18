# Android の WebView が開くロック画面。token で端末を特定する
class LockController < ApplicationController
  layout "lock"

  def show
    @device = Device.find_by(token: params[:token])
    @theme = "jail"
  end
end
