require "test_helper"

class Admin::DevicesControllerTest < ActionDispatch::IntegrationTest
  def auth
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin") }
  end

  test "管理トップが描画される（承認待ち・全員操作フォームを含む）" do
    device = Device.create!(name: "A", locked: true)
    device.break_requests.create!(kind: "break")

    get admin_root_path, headers: auth
    assert_response :success
    assert_select "form.request-approve"              # 承認フォーム
    assert_select ".bulk-lock-screen"                 # 全員一括設定
    assert_match "休憩", response.body                 # 承認待ちリクエストのラベル
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
