require "test_helper"

class ExpireBreakRequestJobTest < ActiveJob::TestCase
  setup { @device = Device.create!(name: "job") }

  test "期限切れの pending は expired にする" do
    req = @device.break_requests.create!(kind: "break")
    req.update_column(:expires_at, 1.minute.ago)
    ExpireBreakRequestJob.perform_now(req.id)
    assert_equal "expired", req.reload.status
  end

  test "pending 以外（承認・取り消し済みなど）には何もしない" do
    %w[approved denied cancelled expired].each do |status|
      req = @device.break_requests.create!(kind: "break")
      # 期限は過ぎていても、pending でなければ触らない
      req.update_columns(status: status, expires_at: 1.minute.ago)
      ExpireBreakRequestJob.perform_now(req.id)
      assert_equal status, req.reload.status, "#{status} が書き換えられてはいけない"
      req.destroy # 次のループで open の重複にならないよう片付ける
    end
  end

  test "存在しない id でも落ちない" do
    assert_nothing_raised { ExpireBreakRequestJob.perform_now(-1) }
  end
end
