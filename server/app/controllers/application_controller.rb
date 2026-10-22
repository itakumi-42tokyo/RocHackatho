class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  LOCK_DEVICE_COOKIE = :lock_device_id

  private

  # 端末を署名付き Cookie に記録する。これ以降トークンは URL に出さない。
  # secure は本番のみ（開発では http でも保持できるようにする）。
  def sign_in_device(device)
    cookies.signed[LOCK_DEVICE_COOKIE] = {
      value: device.id,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }
  end

  # Cookie から今の端末を取り出す（ロック画面・リクエスト送信で使う）
  def current_lock_device
    return @current_lock_device if defined?(@current_lock_device)

    id = cookies.signed[LOCK_DEVICE_COOKIE]
    @current_lock_device = id ? Device.find_by(id: id) : nil
  end

  # JSON API 用。Authorization: Bearer <token> で端末を特定する
  def device_from_bearer
    token = request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]
    Device.find_by(token: token) if token.present?
  end
end
