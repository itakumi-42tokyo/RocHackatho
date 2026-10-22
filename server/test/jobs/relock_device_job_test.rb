require "test_helper"

class RelockDeviceJobTest < ActiveJob::TestCase
  test "端末へ現在の状態を送り直す" do
    device = Device.create!(name: "relock", locked: true, unlock_until: 1.minute.ago)
    assert_broadcasts(DeviceChannel.broadcasting_for(device), 1) do
      RelockDeviceJob.perform_now(device.id)
    end
  end

  test "存在しない端末でも落ちない" do
    assert_nothing_raised { RelockDeviceJob.perform_now(-1) }
  end
end
