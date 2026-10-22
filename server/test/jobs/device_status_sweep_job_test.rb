require "test_helper"

class DeviceStatusSweepJobTest < ActiveJob::TestCase
  test "OFFLINE_AFTER を超えたロック中端末を offline にし、脱獄を1回数える" do
    device = Device.create!(
      name: "A", status: "online", locked: true, locked_at: 2.minutes.ago,
      last_seen_at: (Device::OFFLINE_AFTER + 10).seconds.ago
    )
    DeviceStatusSweepJob.perform_now
    device.reload
    assert_equal "offline", device.status
    assert_equal 1, device.escape_count
  end

  test "INACTIVE_AFTER を超え OFFLINE 未満なら inactive（脱獄は数えない）" do
    device = Device.create!(
      name: "A", status: "online", locked: true, locked_at: 2.minutes.ago,
      last_seen_at: (Device::INACTIVE_AFTER + 5).seconds.ago
    )
    DeviceStatusSweepJob.perform_now
    device.reload
    assert_equal "inactive", device.status
    assert_equal 0, device.escape_count
  end

  test "一時解除中はオフラインでも脱獄に数えない（逃げ得にしない方の逆：使ってよい時間）" do
    device = Device.create!(
      name: "A", status: "online", locked: true, locked_at: 2.minutes.ago,
      unlock_until: 5.minutes.from_now,
      last_seen_at: (Device::OFFLINE_AFTER + 10).seconds.ago
    )
    DeviceStatusSweepJob.perform_now
    device.reload
    assert_equal "offline", device.status
    assert_equal 0, device.escape_count
  end
end
