require "test_helper"

class RelockDeviceJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  # 発火時に「今の unlock_until」で実効ロックを計算し直して送る（強制ロックしない）
  test "期限切れ後に発火すると locked=true を送る（自動再ロック）" do
    device = Device.create!(name: "relock", locked: true, unlock_until: 1.minute.ago)
    msgs = capture_broadcasts(DeviceChannel.broadcasting_for(device)) do
      RelockDeviceJob.perform_now(device.id)
    end
    assert_equal true, msgs.last["locked"]
  end

  # フェーズ4で延長を入れると、延長前の時刻に古いジョブが発火する。
  # そのとき unlock_until はまだ未来なので、強制ロックせず「解除状態」を送るだけにする。
  test "unlock_until が未来のまま発火しても強制ロックせず解除状態を送る" do
    device = Device.create!(name: "relock2", locked: true, unlock_until: 10.minutes.from_now)
    msgs = capture_broadcasts(DeviceChannel.broadcasting_for(device)) do
      RelockDeviceJob.perform_now(device.id)
    end
    assert_equal false, msgs.last["locked"]
  end

  test "存在しない端末でも落ちない" do
    assert_nothing_raised { RelockDeviceJob.perform_now(-1) }
  end
end
