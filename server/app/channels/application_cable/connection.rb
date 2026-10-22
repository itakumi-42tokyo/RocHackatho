module ApplicationCable
  class Connection < ActionCable::Connection::Base
    # current_device は Android からの接続のときだけ入る。管理画面（ブラウザ）の接続では nil
    identified_by :current_device

    def connect
      self.current_device = find_device
      # 「相手はブラウザだけじゃない」。どの経路で端末を特定したかを残す（実機確認・発表用）
      logger.info "Cable 接続: device=#{current_device&.id || 'なし'} 経路=#{@identified_via || 'なし(管理画面など)'}"
    end

    private

    # ネイティブ（OkHttp）は token、ブラウザ／WebView は署名付き Cookie で端末を特定する。
    # どちらでもない接続（管理画面など）は current_device を持たない（nil のまま）。
    def find_device
      if (device = device_from_token)
        @identified_via = "token"
        device
      elsif (device = device_from_cookie)
        @identified_via = "cookie"
        device
      end
    end

    # token は Android が ?token=… かヘッダー Authorization: Bearer … で渡す
    def device_from_token
      token = request.params[:token].presence || bearer_token
      Device.find_by(token: token) if token.present?
    end

    # WebView の Turbo 接続は Cookie を送る。HTTP と同じ署名付き Cookie で端末を特定する
    def device_from_cookie
      Device.from_lock_cookie(cookies.signed[ApplicationController::LOCK_DEVICE_COOKIE])
    end

    def bearer_token
      request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]
    end
  end
end
