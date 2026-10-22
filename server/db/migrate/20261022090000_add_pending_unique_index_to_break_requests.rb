class AddPendingUniqueIndexToBreakRequests < ActiveRecord::Migration[8.0]
  def change
    # 「1 端末につき未処理（pending）は 1 件」を DB レベルで保証する（競合での二重作成を防ぐ）。
    # 期限切れは作成前に expired へ掃除するので、pending のまま残らない。
    add_index :break_requests, :device_id, unique: true,
              where: "status = 'pending'", name: "index_break_requests_pending_unique"
  end
end
