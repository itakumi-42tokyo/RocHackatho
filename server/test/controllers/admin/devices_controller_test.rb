require "test_helper"

class Admin::DevicesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def auth
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin") }
  end

  test "管理トップが描画される（承認待ち・全員操作フォームを含む）" do
    device = Device.create!(name: "A", locked: true)
    device.break_requests.create!(kind: "break")

    get admin_root_path, headers: auth
    assert_response :success
    assert_select "meta[name=?][content=?]", "turbo-refresh-method", "morph" # morph 配信を受ける
    assert_select "turbo-cable-stream-source"         # "admin" を購読している
    assert_select "#pending_banner"                   # 承認待ちバナー
    assert_select "form.request-approve"              # 承認フォーム
    assert_select ".bulk-lock-screen"                 # 全員一括設定
    assert_match "休憩", response.body                 # 承認待ちリクエストのラベル
  end

  test "延長で unlock_until が伸び、再ロックジョブが予約される" do
    device = Device.create!(name: "A", locked: true, unlock_until: 2.minutes.from_now)
    before = device.unlock_until
    assert_enqueued_with(job: RelockDeviceJob) do
      patch extend_unlock_admin_device_path(device, minutes: 10),
            headers: auth.merge("Accept" => "text/vnd.turbo-stream.html")
    end
    assert_response :no_content
    assert device.reload.unlock_until > before
  end

  test "今すぐ再ロックで unlock_until が消える" do
    device = Device.create!(name: "A", locked: true, unlock_until: 5.minutes.from_now)
    patch relock_admin_device_path(device), headers: auth.merge("Accept" => "text/vnd.turbo-stream.html")
    assert_response :no_content
    assert_nil device.reload.unlock_until
    assert device.effective_locked?
  end

  test "全員操作で lock_title / lock_buttons を一括設定できる" do
    d1 = Device.create!(name: "A")
    d2 = Device.create!(name: "B")

    post update_lock_screen_admin_devices_path,
         params: { lock_title: "会議中", buttons_preset: "toilet_only" }, headers: auth
    assert_redirected_to admin_root_path

    [d1, d2].each do |d|
      d.reload
      assert_equal "会議中", d.lock_title
      assert_equal [{ "label" => "トイレ", "kind" => "toilet" }], d.lock_buttons
    end
  end
end
