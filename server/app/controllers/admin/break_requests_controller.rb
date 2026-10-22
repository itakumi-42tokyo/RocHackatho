class Admin::BreakRequestsController < Admin::BaseController
  before_action :set_break_request

  # 承認：分数（プリセット）と任意の返信。端末には一時解除が届き、時刻が来たら自動再ロック
  def approve
    @break_request.approve!(minutes: params[:minutes], reply: params[:reply])
    respond_back
  end

  # 却下：返信（理由）つき
  def deny
    @break_request.deny!(reply: params[:reply])
    respond_back
  end

  private

  def set_break_request
    @break_request = BreakRequest.find(params[:id])
  end

  # 画面は broadcast（端末のロック画面・管理画面の両方）で更新されるので、ここは何も描かない
  def respond_back
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to admin_root_path }
    end
  end
end
