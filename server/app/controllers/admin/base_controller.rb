class Admin::BaseController < ApplicationController
  # 本番では ADMIN_USER / ADMIN_PASSWORD を必須にする（未設定なら起動時にエラー）。
  # 開発・テストでは admin/admin にフォールバックする。
  def self.fetch_admin_credential(key, production: Rails.env.production?)
    ENV.fetch(key) do
      raise "本番環境では環境変数 #{key} を設定してください（既定値にはフォールバックしません）" if production
      "admin"
    end
  end

  http_basic_authenticate_with(
    name: fetch_admin_credential("ADMIN_USER"),
    password: fetch_admin_credential("ADMIN_PASSWORD")
  )
  layout "admin"
end
