class AddUnlockUntilToDevices < ActiveRecord::Migration[8.0]
  def change
    # 一時解除の期限。locked は変えず、これで「実効ロック」を計算する。
    # 承認時に now + 分数 を入れ、この時刻に状態を送り直して自動再ロックする。
    add_column :devices, :unlock_until, :datetime
  end
end
