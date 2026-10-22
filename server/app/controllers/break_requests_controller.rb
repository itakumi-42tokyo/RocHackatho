# ロック画面からの休憩リクエストの受け口。
# 端末は署名付き Cookie で特定し（トークンは URL に残さない）、Rails 標準の CSRF 対策を使う。
class BreakRequestsController < ApplicationController
  layout "lock"

  before_action :require_lock_device

  # 連打対策はサーバー側で行う（画面側のボタン無効化だけに頼らない）。端末ごとに制限する。
  # 保存先はアプリのキャッシュ（本番は solid_cache = 複数プロセスで共有）。test は memory_store。
  rate_limit to: 2, within: 10.seconds,
             by: -> { current_lock_device&.id },
             with: -> { rate_limit_exceeded },
             only: :create

  def create
    # 期限切れの pending を先に片づけてから作る（部分ユニークインデックスと整合させる）
    BreakRequest.expire_due_for(current_lock_device)

    @break_request = current_lock_device.break_requests.new(create_params)
    saved =
      begin
        @break_request.save
      rescue ActiveRecord::RecordNotUnique
        # 競合で未処理が二重になりかけたとき（DB の部分ユニークインデックスが弾く）
        @break_request.errors.add(:base, "すでに承認待ちのリクエストがあります")
        false
      end
    if saved
      ExpireBreakRequestJob.set(wait_until: @break_request.expires_at).perform_later(@break_request.id)
    end

    respond_to do |format|
      format.turbo_stream do
        render_request_zone(error: (saved ? nil : @break_request.errors.full_messages.to_sentence),
                            status: (saved ? :ok : :unprocessable_entity))
      end
      format.html { redirect_to lock_path }
    end
  end

  # 自分の pending リクエストを取り消す。他端末のものには触れない（Cookie の端末で絞り込む）
  def cancel
    req = current_lock_device.break_requests.find_by(id: params[:id])
    req&.cancel!

    respond_to do |format|
      format.turbo_stream { render_request_zone }
      format.html { redirect_to lock_path }
    end
  end

  private

  def create_params
    params.require(:break_request).permit(:kind, :body)
  end

  def require_lock_device
    redirect_to lock_path unless current_lock_device
  end

  def render_request_zone(error: nil, status: :ok)
    render turbo_stream: turbo_stream.replace(
      "lock_request_zone",
      partial: "lock/request_zone",
      locals: { device: current_lock_device.reload, error: error }
    ), status: status
  end

  def rate_limit_exceeded
    respond_to do |format|
      format.turbo_stream { render_request_zone(error: "少し待ってからもう一度試してください", status: :too_many_requests) }
      format.html { redirect_to lock_path, alert: "少し待ってからもう一度試してください" }
    end
  end
end
