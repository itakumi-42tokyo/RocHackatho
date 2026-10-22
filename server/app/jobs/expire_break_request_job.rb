# 承認待ちのまま期限が来たリクエストを expired にする。
# 作成時に set(wait_until: expires_at) で予約する。
class ExpireBreakRequestJob < ApplicationJob
  queue_as :default

  def perform(break_request_id)
    BreakRequest.find_by(id: break_request_id)&.expire_if_due!
  end
end
