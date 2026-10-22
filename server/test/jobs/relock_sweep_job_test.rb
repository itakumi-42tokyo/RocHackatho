require "test_helper"

class RelockSweepJobTest < ActiveJob::TestCase
  test "期限切れの一時解除を拾って再ロックを確定する（unlock_until を消す）" do
    device = Device.create!(name: "A", locked: true, unlock_until: 1.minute.ago)
    RelockSweepJob.perform_now
    assert_nil device.reload.unlock_until
    assert device.effective_locked?
  end

  test "まだ解除中（unlock_until が未来）の端末は触らない" do
    device = Device.create!(name: "A", locked: true, unlock_until: 5.minutes.from_now)
    RelockSweepJob.perform_now
    assert device.reload.unlock_until.present?
    refute device.effective_locked?
  end

  test "ロックしていない端末は対象外" do
    device = Device.create!(name: "A", locked: false, unlock_until: 1.minute.ago)
    RelockSweepJob.perform_now
    assert device.reload.unlock_until.present? # 触らない
  end
end
