class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  LOCK_DEVICE_COOKIE = :lock_device_id

  private

  # 端末を署名付き Cookie に記録する。これ以降トークンは URL に出さない。
  # secure は本番のみ（開発では http でも保持できるようにする）。
  # id だけでなく token の世代も入れ、token を回転させたら古い Cookie を無効にできるようにする。
  def sign_in_device(device)
    cookies.signed[LOCK_DEVICE_COOKIE] = {
      value: { "id" => device.id, "gen" => device.token_generation },
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }
  end

  # Cookie から今の端末を取り出す（ロック画面・リクエスト送信で使う）
  def current_lock_device
    return @current_lock_device if defined?(@current_lock_device)

    @current_lock_device = Device.from_lock_cookie(cookies.signed[LOCK_DEVICE_COOKIE])
  end

  # JSON API 用。Authorization: Bearer <token> で端末を特定する
  def device_from_bearer
    token = request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]
    Device.find_by(token: token) if token.present?
  end
end
