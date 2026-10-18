module ApplicationCable
  class Connection < ActionCable::Connection::Base
    # current_device は Android からの接続のときだけ入る。管理画面（ブラウザ）の接続では nil
    identified_by :current_device

    def connect
      self.current_device = find_device
    end

    private

    # token は Android が ?token=… かヘッダー Authorization: Bearer … で渡す
    def find_device
      token = request.params[:token].presence || bearer_token
      Device.find_by(token: token) if token.present?
    end

    def bearer_token
      request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]
    end
  end
end
