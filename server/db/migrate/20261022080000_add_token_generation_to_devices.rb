class AddTokenGenerationToDevices < ActiveRecord::Migration[8.0]
  def change
    # 署名付き Cookie に世代番号を埋め、token を回転させたら古い Cookie を無効にできるようにする
    add_column :devices, :token_generation, :integer, default: 0, null: false
  end
end
