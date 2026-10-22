require "test_helper"

class BreakRequestTest < ActiveSupport::TestCase
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
end
