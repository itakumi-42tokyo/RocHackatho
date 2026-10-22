require "test_helper"

# full モードは複数の接続（LockService・アクティビティ・オーバーレイ）から
# 同時に「脱獄／復帰」が報告されうる。順番どおりのテストでは出ない競合なので、
# スレッドを2つ使って「同時報告でも記録は1回だけ」を固定する。
# （スレッドが別コネクションで実データを見られるよう、このクラスは非トランザクション）
class DeviceConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    DeviceEvent.delete_all
    BreakRequest.delete_all
    Device.delete_all
  end

  def run_in_parallel(n, device_id, &block)
    n.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Device.find(device_id).instance_eval(&block)
        end
      end
    end.each(&:join)
  end

  test "同時に2つの脱獄報告が来てもカウントは1回だけ" do
    device = Device.create!(name: "A", locked: true, locked_at: 1.minute.ago, escaped: false)

    run_in_parallel(2, device.id) { mark_escaped! }

    device.reload
    assert device.escaped?
    assert_equal 1, device.escape_count, "同時報告で二重カウントしている"
    assert_equal 1, DeviceEvent.where(device_id: device.id, kind: "escaped").count
  end

  test "同時に2つの連れ戻し報告が来ても recaptured は1回だけ" do
    device = Device.create!(name: "A", locked: true, locked_at: 1.minute.ago, escaped: true)

    run_in_parallel(2, device.id) { mark_recaptured! }

    device.reload
    refute device.escaped?
    assert_equal 1, DeviceEvent.where(device_id: device.id, kind: "recaptured").count
  end
end
