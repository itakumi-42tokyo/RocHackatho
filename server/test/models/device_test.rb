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

  test "一時解除中は脱獄に数えない（mark_escaped! は何もしない）" do
    @device.update!(locked: true, locked_at: 1.minute.ago, unlock_until: 5.minutes.from_now)
    assert_no_difference -> { @device.reload.escape_count } do
      @device.mark_escaped!
    end
  end

  test "実効ロック中は脱獄に数える" do
    @device.update!(locked: true, locked_at: 1.minute.ago, unlock_until: nil)
    assert_difference -> { @device.reload.escape_count }, 1 do
      @device.mark_escaped!
    end
  end

  test "脱獄は状態変化1回につき1回だけ（ハートビート連打でも増えない）" do
    @device.update!(locked: true, locked_at: 1.minute.ago, unlock_until: nil, escaped: false)
    assert_difference -> { @device.reload.escape_count }, 1 do
      5.times { @device.mark_escaped! } # report が何度来ても +1 のみ
    end
    assert @device.reload.escaped?
  end

  test "recapture すると escaped が戻り、また逃げれば再び数える" do
    @device.update!(locked: true, locked_at: 1.minute.ago, escaped: false)
    @device.mark_escaped!
    @device.mark_recaptured!
    refute @device.reload.escaped?
    assert_difference -> { @device.reload.escape_count }, 1 do
      @device.mark_escaped!
    end
  end

  test "register! は client_id が新規なら作成し、同じ client_id なら行を再利用して token を作り直す" do
    first = nil
    assert_difference -> { Device.count }, 1 do
      first = Device.register!(client_id: "same", name: "一回目")
    end
    old_token = first.token
    old_gen = first.token_generation

    again = nil
    assert_no_difference -> { Device.count } do
      again = Device.register!(client_id: "same", name: "二回目")
    end
    assert_equal first.id, again.id           # 同じ端末（重複行を作らない）
    refute_equal old_token, again.token        # token を作り直す
    assert again.token_generation > old_gen    # 世代が上がる＝旧 Cookie も無効
    assert_equal "二回目", again.name
  end

  test "register! は client_id 無しなら毎回新規" do
    assert_difference -> { Device.count }, 2 do
      Device.register!(client_id: nil, name: "A")
      Device.register!(client_id: "", name: "B")
    end
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
