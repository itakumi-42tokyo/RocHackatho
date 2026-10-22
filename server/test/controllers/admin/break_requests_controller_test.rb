require "test_helper"

class Admin::BreakRequestsControllerTest < ActionDispatch::IntegrationTest
  # 管理画面は Turbo でフォーム送信するので、承認・却下は turbo_stream で受ける（204）
  def auth
    {
      "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin"),
      "Accept" => "text/vnd.turbo-stream.html"
    }
  end

  setup do
    @device = Device.create!(name: "A", locked: true)
    @req = @device.break_requests.create!(kind: "break")
  end

  test "認証なしでは承認できない" do
    patch approve_admin_break_request_path(@req), params: { minutes: 10 }
    assert_response :unauthorized
    assert_equal "pending", @req.reload.status
  end

  test "承認すると approved になり端末が一時解除される" do
    patch approve_admin_break_request_path(@req), params: { minutes: 15, reply: "どうぞ" }, headers: auth
    assert_response :no_content
    @req.reload
    assert_equal "approved", @req.status
    assert_equal 15, @req.unlock_minutes
    assert_equal "どうぞ", @req.reply
    assert @device.reload.unlock_until&.future?
    refute @device.effective_locked?
  end

  test "却下すると denied になり返信が残る" do
    patch deny_admin_break_request_path(@req), params: { reply: "今は無理" }, headers: auth
    assert_response :no_content
    @req.reload
    assert_equal "denied", @req.status
    assert_equal "今は無理", @req.reply
  end
end
