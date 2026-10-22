require "test_helper"

# Cable 接続の端末識別の配線確認。
# token と「どちらも無い」ケースをここで確認する。
# 署名付き Cookie 経路の中核（世代チェック）は Device.from_lock_cookie の単体テストと、
# HTTP 統合テスト（current_lock_device 経由）で検証している
#（ActionCable の TestCase は署名 Cookie を接続のリクエストに載せないため、ここでは扱わない）。
class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "token で端末を識別する" do
    device = Device.create!(name: "C")
    connect params: { token: device.token }
    assert_equal device.id, connection.current_device.id
  end

  test "token も Cookie も無ければ current_device は nil（管理画面など）" do
    connect
    assert_nil connection.current_device
  end
end
