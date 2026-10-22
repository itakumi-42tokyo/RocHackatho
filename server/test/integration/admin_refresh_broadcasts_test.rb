require "test_helper"
require "turbo/broadcastable/test_helper"

# 管理画面は Turbo 8 のページリフレッシュ（morph）で更新する。
# 端末の登録・休憩リクエストの作成/承認/却下/取り消しで "admin" に refresh が配信されることを確認する。
# after_commit を実際に発火させたいので、このクラスだけトランザクションを使わない。
class AdminRefreshBroadcastsTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  self.use_transactional_tests = false

  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  setup { Rails.cache.clear }

  teardown do
    BreakRequest.delete_all
    DeviceEvent.delete_all
    Device.delete_all
  end

  def admin_auth
    {
      "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin"),
      "Accept" => "text/vnd.turbo-stream.html"
    }
  end

  def sign_in_device(device)
    get lock_path(token: device.token)
    follow_redirect!
  end

  test "端末の新規登録で admin に refresh が配信される" do
    assert_turbo_stream_broadcasts "admin" do
      post api_devices_path, params: { client_id: "c1", name: "A" }
    end
  end

  test "休憩リクエストの作成で admin に refresh が配信される" do
    device = Device.create!(name: "A", locked: true)
    sign_in_device(device)
    assert_turbo_stream_broadcasts "admin" do
      post break_requests_path, params: { break_request: { kind: "break" } }, headers: TURBO
    end
  end

  test "承認で admin に refresh が配信される" do
    device = Device.create!(name: "A", locked: true)
    req = device.break_requests.create!(kind: "break")
    assert_turbo_stream_broadcasts "admin" do
      patch approve_admin_break_request_path(req), params: { minutes: 10 }, headers: admin_auth
    end
  end

  test "却下で admin に refresh が配信される" do
    device = Device.create!(name: "A", locked: true)
    req = device.break_requests.create!(kind: "break")
    assert_turbo_stream_broadcasts "admin" do
      patch deny_admin_break_request_path(req), params: { reply: "x" }, headers: admin_auth
    end
  end

  test "見た目が変わらない更新（last_seen_at のみ）では配信しない" do
    device = Device.create!(name: "A")
    assert_turbo_stream_broadcasts "admin", count: 0 do
      device.update!(last_seen_at: Time.current)   # ハートビート相当
    end
  end

  test "status が変わると配信する" do
    device = Device.create!(name: "A", status: "online")
    assert_turbo_stream_broadcasts "admin" do
      device.update!(status: "offline")
    end
  end

  test "取り消しで admin に refresh が配信される" do
    device = Device.create!(name: "A", locked: true)
    req = device.break_requests.create!(kind: "break")
    sign_in_device(device)
    assert_turbo_stream_broadcasts "admin" do
      patch cancel_break_request_path(req), headers: TURBO
    end
  end
end
