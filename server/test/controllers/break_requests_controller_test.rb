require "test_helper"

class BreakRequestsControllerTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  setup do
    # rate_limit はキャッシュを使い、ロールバックで端末 ID が再利用されるため、テストごとにクリアする
    Rails.cache.clear
    @device = Device.create!(name: "A")
    @other  = Device.create!(name: "B")
  end

  # ?token=… で一度アクセスすると署名付き Cookie が入り、以降その端末として扱われる
  def sign_in(device)
    get lock_path(token: device.token)
    assert_redirected_to lock_path # トークンは URL に残さずリダイレクトする
    follow_redirect!
  end

  test "トークン付きアクセスは Cookie を発行してリダイレクトする（URL にトークンを残さない）" do
    get lock_path(token: @device.token)
    assert_redirected_to lock_path
    follow_redirect!
    assert_response :success
  end

  test "ロック画面に Turbo ストリーム購読と送信フォームが出る" do
    sign_in(@device)
    get lock_path
    assert_response :success
    assert_select "turbo-cable-stream-source" # 端末専用ストリームを購読している
    assert_select "#lock_request_zone"
    assert_match "休憩したい", response.body
    assert_match "トイレ", response.body
  end

  test "custom ボタンのときは文字数上限つきの自由入力欄が出る" do
    @device.update!(lock_buttons: [{ "label" => "その他", "kind" => "custom" }])
    sign_in(@device)
    get lock_path
    assert_select "input.lock-input[maxlength=?]", BreakRequest::BODY_MAX.to_s
  end

  test "ロック画面からリクエストを送れる" do
    sign_in(@device)
    assert_difference -> { @device.break_requests.count }, 1 do
      post break_requests_path, params: { break_request: { kind: "break" } }, headers: TURBO
    end
    assert_response :success
    req = @device.break_requests.last
    assert_equal "break", req.kind
    assert_equal "pending", req.status
  end

  test "custom は body が必要" do
    sign_in(@device)
    assert_no_difference -> { @device.break_requests.count } do
      post break_requests_path, params: { break_request: { kind: "custom", body: "" } }, headers: TURBO
    end
    assert_response :unprocessable_entity
  end

  test "1 端末につき未処理は 1 件だけ" do
    sign_in(@device)
    post break_requests_path, params: { break_request: { kind: "break" } }, headers: TURBO
    assert_response :success
    assert_no_difference -> { @device.break_requests.count } do
      post break_requests_path, params: { break_request: { kind: "toilet" } }, headers: TURBO
    end
    assert_response :unprocessable_entity
  end

  test "連打はサーバー側で弾く（rate limit）" do
    sign_in(@device)
    # 取り消して pending を無くしつつ、短時間に create を繰り返す
    post break_requests_path, params: { break_request: { kind: "break" } }, headers: TURBO
    @device.break_requests.last.update!(status: "cancelled")
    post break_requests_path, params: { break_request: { kind: "break" } }, headers: TURBO
    @device.break_requests.where(status: "pending").last&.update!(status: "cancelled")
    # 制限（10 秒で 2 回）を超える 3 回目
    post break_requests_path, params: { break_request: { kind: "break" } }, headers: TURBO
    assert_response :too_many_requests
  end

  test "期限切れの pending は新規作成をブロックしない" do
    sign_in(@device)
    post break_requests_path, params: { break_request: { kind: "break" } }, headers: TURBO
    assert_response :success
    @device.break_requests.last.update_column(:expires_at, 1.minute.ago)
    assert_difference -> { @device.break_requests.count }, 1 do
      post break_requests_path, params: { break_request: { kind: "toilet" } }, headers: TURBO
    end
    assert_response :success
  end

  test "自分の pending を取り消せる" do
    sign_in(@device)
    post break_requests_path, params: { break_request: { kind: "break" } }, headers: TURBO
    req = @device.break_requests.last
    patch cancel_break_request_path(req), headers: TURBO
    assert_response :success
    assert_equal "cancelled", req.reload.status
  end

  test "他端末のリクエストには触れない" do
    sign_in(@device)
    post break_requests_path, params: { break_request: { kind: "break" } }, headers: TURBO
    req = @device.break_requests.last

    sign_in(@other) # Cookie を別端末に切り替える
    patch cancel_break_request_path(req), headers: TURBO
    # 他端末のものなので取り消されない
    assert_equal "pending", req.reload.status
  end

  test "Cookie が無ければリクエストは受け付けずロック画面へ戻す" do
    post break_requests_path, params: { break_request: { kind: "break" } }, headers: TURBO
    assert_redirected_to lock_path
  end
end
