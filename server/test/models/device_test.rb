require "test_helper"

class DeviceTest < ActiveSupport::TestCase
  setup { @device = Device.create!(name: "dev", locked: true) }

  test "effective_locked? はロック中かつ一時解除の期限切れ" do
    assert @device.effective_locked?, "unlock_until が nil なら実効ロック"

    @device.update!(unlock_until: 5.minutes.from_now)
    refute @device.effective_locked?, "未来の unlock_until があるあいだは解除扱い"

    @device.update!(unlock_until: 1.minute.ago)
    assert @device.effective_locked?, "期限が過ぎたら再びロック"
  end

  test "ロックしていなければ unlock_until に関わらず解除" do
    @device.update!(locked: false, unlock_until: 5.minutes.from_now)
    refute @device.effective_locked?
  end

  test "state_payload の locked は実効ロックを返す" do
    @device.update!(unlock_until: 5.minutes.from_now)
    refute @device.state_payload[:locked]
    @device.update!(unlock_until: 1.minute.ago)
    assert @device.state_payload[:locked]
  end

  test "grant_break! は unlock_until を now+分 にする" do
    freeze_time do
      @device.grant_break!(10)
      assert_in_delta 10.minutes.from_now, @device.unlock_until, 1.second
    end
  end

  test "unlock_remaining_seconds は未来のときだけ正、それ以外は 0" do
    @device.update!(unlock_until: 30.seconds.from_now)
    assert @device.unlock_remaining_seconds.positive?
    @device.update!(unlock_until: 1.minute.ago)
    assert_equal 0, @device.unlock_remaining_seconds
  end

  test "手動 lock! / unlock! は unlock_until を消す（手動操作を優先）" do
    @device.update!(unlock_until: 5.minutes.from_now)
    @device.lock!
    assert_nil @device.unlock_until
    assert @device.effective_locked?

    @device.update!(unlock_until: 5.minutes.from_now)
    @device.unlock!
    assert_nil @device.unlock_until
  end
end
