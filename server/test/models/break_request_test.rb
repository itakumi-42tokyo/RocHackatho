require "test_helper"

class BreakRequestTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @device = Device.create!(name: "テスト端末")
  end

  test "kind は既知の値だけ許可する" do
    assert BreakRequest.new(device: @device, kind: "break").valid?
    refute BreakRequest.new(device: @device, kind: "unknown").valid?
  end

  test "custom は body が必須" do
    refute BreakRequest.new(device: @device, kind: "custom").valid?
    assert BreakRequest.new(device: @device, kind: "custom", body: "お手洗い").valid?
  end

  test "body は上限文字数まで" do
    refute BreakRequest.new(device: @device, kind: "break", body: "あ" * (BreakRequest::BODY_MAX + 1)).valid?
    assert BreakRequest.new(device: @device, kind: "break", body: "あ" * BreakRequest::BODY_MAX).valid?
  end

  test "作成時に pending と expires_at が入る" do
    req = @device.break_requests.create!(kind: "break")
    assert_equal "pending", req.status
    assert req.expires_at.present?
    assert req.open?
  end

  test "同じ端末で未処理は 1 件しか作れない" do
    @device.break_requests.create!(kind: "break")
    second = @device.break_requests.new(kind: "toilet")
    refute second.save
    assert_includes second.errors.full_messages.join, "承認待ち"
  end

  test "他端末には影響しない（別端末は未処理を作れる）" do
    @device.break_requests.create!(kind: "break")
    other = Device.create!(name: "別端末")
    assert other.break_requests.new(kind: "break").save
  end

  test "cancel! で cancelled になり open から外れる" do
    req = @device.break_requests.create!(kind: "break")
    assert req.cancel!
    assert_equal "cancelled", req.status
    assert_nil @device.open_break_request
    # 取り消したあとは新しく作れる
    assert @device.break_requests.new(kind: "toilet").save
  end

  test "expire_if_due! は期限切れの pending を expired にする" do
    req = @device.break_requests.create!(kind: "break")
    refute req.expire_if_due! # まだ期限内
    req.update_column(:expires_at, 1.minute.ago)
    assert req.expire_if_due!
    assert_equal "expired", req.status
    assert_nil @device.open_break_request
  end

  test "open スコープは期限切れの pending を含まない" do
    req = @device.break_requests.create!(kind: "break")
    assert_includes BreakRequest.open, req
    req.update_column(:expires_at, 1.minute.ago)
    refute_includes BreakRequest.open, req
  end

  test "approve! は承認し、端末に一時解除を与え、再ロックジョブを予約する" do
    device = Device.create!(name: "承認", locked: true)
    req = device.break_requests.create!(kind: "break")

    assert_enqueued_with(job: RelockDeviceJob) do
      assert req.approve!(minutes: 15)
    end

    assert_equal "approved", req.status
    assert_equal 15, req.unlock_minutes
    assert req.responded_at.present?
    assert device.reload.unlock_until&.future?
    refute device.effective_locked?, "承認直後は一時解除されている"
  end

  test "approve! のプリセット外の分数は kind の既定に丸める" do
    req = @device.break_requests.create!(kind: "toilet")
    req.approve!(minutes: 999) # プリセット外
    assert_equal 5, req.unlock_minutes # toilet の既定
  end

  test "deny! は却下して返信を残す" do
    req = @device.break_requests.create!(kind: "break")
    assert req.deny!(reply: "あとで")
    assert_equal "denied", req.status
    assert_equal "あとで", req.reply
  end

  test "pending 以外は approve!/deny! できない" do
    req = @device.break_requests.create!(kind: "break")
    req.update!(status: "cancelled")
    refute req.approve!(minutes: 10)
    refute req.deny!(reply: "x")
  end

  test "default_minutes は kind ごと" do
    assert_equal 5, BreakRequest.new(kind: "toilet").default_minutes
    assert_equal 10, BreakRequest.new(kind: "break").default_minutes
    assert_equal 10, BreakRequest.new(kind: "custom").default_minutes
  end

  test "expire_due_for は期限切れの pending だけ expired にする" do
    expired = @device.break_requests.create!(kind: "break")
    expired.update_column(:expires_at, 1.minute.ago)
    alive = Device.create!(name: "別").break_requests.create!(kind: "toilet")

    BreakRequest.expire_due_for(@device)

    assert_equal "expired", expired.reload.status
    assert_equal "pending", alive.reload.status # 別端末・期限内は変えない
  end
end

class DeviceLockCookieTest < ActiveSupport::TestCase
  setup { @device = Device.create!(name: "cookie") }

  test "世代が一致する Cookie からは端末を返す" do
    data = { "id" => @device.id, "gen" => @device.token_generation }
    assert_equal @device, Device.from_lock_cookie(data)
  end

  test "世代が違う Cookie は弾く" do
    data = { "id" => @device.id, "gen" => @device.token_generation + 1 }
    assert_nil Device.from_lock_cookie(data)
  end

  test "Hash でない・id 不明の Cookie は nil" do
    assert_nil Device.from_lock_cookie(nil)
    assert_nil Device.from_lock_cookie(123)
    assert_nil Device.from_lock_cookie({ "id" => -1, "gen" => 0 })
  end

  test "rotate_token! で token が変わり世代が上がる（旧 Cookie が無効になる）" do
    old_data = { "id" => @device.id, "gen" => @device.token_generation }
    old_token = @device.token

    @device.rotate_token!

    refute_equal old_token, @device.token
    assert_nil Device.from_lock_cookie(old_data) # 旧 Cookie はもう通らない
  end
end
