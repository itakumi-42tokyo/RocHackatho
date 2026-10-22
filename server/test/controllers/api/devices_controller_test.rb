require "test_helper"

class Api::DevicesControllerTest < ActionDispatch::IntegrationTest
  test "client_id つき登録で token を返す" do
    assert_difference -> { Device.count }, 1 do
      post api_devices_path, params: { client_id: "dev-1", name: "A" }
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert body["token"].present?
    assert_equal "A", body["name"]
  end

  test "同じ client_id の再登録は同じ端末・新しい token" do
    post api_devices_path, params: { client_id: "dev-2", name: "A" }
    first = JSON.parse(response.body)

    assert_no_difference -> { Device.count } do
      post api_devices_path, params: { client_id: "dev-2", name: "A2" }
    end
    second = JSON.parse(response.body)

    assert_equal first["id"], second["id"]      # 同じ端末
    refute_equal first["token"], second["token"] # token は作り直し（古い方は無効）
  end
end
