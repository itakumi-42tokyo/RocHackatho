require "test_helper"

class DeviceChannelTest < ActionCable::Channel::TestCase
  test "購読直後に現在の状態を送る（再接続時の取りこぼし防止）" do
    device = Device.create!(name: "A", locked: true)
    stub_connection(current_device: device)

    subscribe

    assert subscription.confirmed?
    state = transmissions.find { |m| m["type"] == "state" }
    assert state, "購読直後に state を送っていない"
    assert_equal true, state["locked"]
    assert_equal device.lock_mode, state["mode"]
  end

  test "一時解除中は購読直後の状態が locked=false（実効ロック）" do
    device = Device.create!(name: "A", locked: true, unlock_until: 5.minutes.from_now)
    stub_connection(current_device: device)

    subscribe

    state = transmissions.find { |m| m["type"] == "state" }
    assert_equal false, state["locked"]
  end

  test "current_device が無ければ reject する" do
    stub_connection(current_device: nil)
    subscribe
    assert subscription.rejected?
  end
end
