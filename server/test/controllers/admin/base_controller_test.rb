require "test_helper"

class Admin::BaseControllerCredentialTest < ActiveSupport::TestCase
  test "環境変数があればその値を使う" do
    ENV["ADMIN_USER"] = "boss"
    assert_equal "boss", Admin::BaseController.fetch_admin_credential("ADMIN_USER", production: true)
  ensure
    ENV.delete("ADMIN_USER")
  end

  test "本番で未設定なら起動時にエラー（既定値にフォールバックしない）" do
    error = assert_raises(RuntimeError) do
      Admin::BaseController.fetch_admin_credential("ADMIN_USER", production: true)
    end
    assert_match "ADMIN_USER", error.message
  end

  test "本番以外は admin にフォールバックする" do
    assert_equal "admin", Admin::BaseController.fetch_admin_credential("ADMIN_PASSWORD", production: false)
  end
end
